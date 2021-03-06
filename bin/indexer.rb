#!/bin/env ruby

# a script intended to be executed from the command line or by cron.
#
# fetches current data from the In adiutorium github repo,
# compiles all chants to separate png images and indexes them in a database.

require 'data_mapper'
require 'fileutils'
require 'optparse'
require 'log4r'
require 'log4r/yamlconfigurator'
require 'open3'

require_relative '../lib/lilytools/musicreader'
require_relative '../lib/eantifonar/config'
require_relative '../lib/eantifonar/model'
require_relative '../lib/eantifonar/lyrictools'

DataMapper::Model.raise_on_save_failure = true

module EAntifonar

  # IndexingStrategy subclasses define a way of saving Chants
  # to the database (save always? check something before?)
  class IndexingStrategy
    def initialize(*any)
    end

    # takes a Chant instance and saves it
    def save_chant(chant, logger)
      unless chant.valid?
        logger.warn "warning: Chant instance invalid: " + chant.inspect
      end
      chant.save
    end

    # checks if the chant should be saved
    def to_save?(chant)
      true
    end
  end

  # if given chant already exists, only save the new
  # if it is different
  class UpdateIndexingStrategy < IndexingStrategy

    def save_chant(chant, logger)
      unless to_save? chant
        return false
      end

      present = get_existing chant

      # the chant changed. delete the original, save the new
      if present then
        destroyed = present.destroy
        unless destroyed
          logger.error "Failed to delete old record of chant #{present.src_path}##{present.score_id}"
          return false
        end
      end

      logger.info "Updating changed/new chant #{chant.src_path}##{chant.score_id}"

      super(chant, logger)
    end

    def to_save?(chant)
      present = get_existing chant

      if present == nil then
        return true
      end

      if present.created >= chant.created
        return false
      end

      if chant.src == present.src then
        return false
      end

      return true
    end

    private

    # returns already saved chant with the same key data
    def get_existing(chant)
      chants = Chant.all(:src_path => chant.src_path, :score_id => chant.score_id, :lyrics_cleaned => chant.lyrics_cleaned)
      if chants.size <= 1 then
        return chants.first
      end

      raise "More chants with src_path #{chant.src_path} score_id #{chant.score_id} and lyrics_cleaned '#{chant.lyrics_cleaned}' found!"
    end
  end

  # saves anything; expects no conflicts
  class ReindexIndexingStrategy < IndexingStrategy

    def initialize(files_to_update=[])
      if files_to_update.empty?
        # drop all data, refresh tables according to the model
        DataMapper.auto_migrate!
        DataMapper.auto_upgrade!
      else
        # drop all data made of the specified files
        files_to_update.each do |f|
          destroyed = Chant.all(:src_path => f).destroy
          unless destroyed
            raise "Failed to delete database entries coming from file #{f}."
          end
        end
      end
    end
  end

  # Indexer takes directory structure of the In adiutorium 'chant-base'
  # and transforms all or some data to database records for E-antifonar
  class Indexer

    DEFAULT_SETUP = {
      # where to look for scores in the In adiutorium project structure -
      :app_root => EAntifonar::CONFIG[:app_root],
      :config_file => File.join('config', 'indexer.yml'), # relative to app_root

      :scores_subdirs => [],
      :skip_files => [],

      :scores_dir => nil, # must be set!
      :files_to_process => [],
      :output_dir => nil,

      :mode => :update # :update | :reindex
    }

    def initialize(setup={}, logger=Log4r::Logger.new('default'))
      @logger = logger

      @setup = DEFAULT_SETUP.dup
      @setup.update(load_config(File.join(@setup[:app_root], @setup[:config_file])))
      @setup.update setup
    end

    # before we start to produce output
    def prepare
      if @setup[:scores_dir] == nil then
        raise "Directory with scores not set. Nothing to do."
      elsif not File.directory? @setup[:scores_dir] then
        raise "Directory with scores '#{@setup[:scores_dir]}' does not exist."
      end

      @setup[:scores_dir] = File.expand_path @setup[:scores_dir]

      if @setup[:output_dir] == nil then
        @setup[:output_dir] = File.join(@setup[:scores_dir], 'eantifonar_tmp')
      end
      unless File.directory? @setup[:output_dir]
        Dir.mkdir @setup[:output_dir]
      end

      indexing_strategy_name = @setup[:mode].to_s.capitalize+'IndexingStrategy'
      @indexing_strategy = EAntifonar.const_get(indexing_strategy_name).new(@setup[:files_to_process])

      # no files specified - scan the whole chant-base
      if @setup[:files_to_process].empty? then
        @setup[:files_to_process] = collect_files
      end

      @setup[:files_to_process] = apply_blacklist @setup[:files_to_process]

      # definitions prepended to each lilypond chunk to make it standalone compilable
      @prepend = File.read(File.expand_path('eantifonar_common.ly', File.join(@setup[:app_root], 'data', 'ly')))

      Dir.chdir @setup[:output_dir] # because we will execute programs expecting this
    end

    # collects and returns a list of all lilypond files
    # in the chantbase according to the configuration
    def collect_files
      files = @setup[:scores_subdirs].collect do |subdir|
        dir = File.join @setup[:scores_dir], subdir
        fullpath = File.join dir, '*.ly'
        Dir[fullpath].collect do |f|
          f.sub(@setup[:scores_dir]+'/', '')  # we only want 'subdir/file.ly'
            .sub('./', '') # and only fily.ly if subdir is '.'
        end
      end
      return files.flatten
    end

    def apply_blacklist(files)
      # apply blacklist
      return files - @setup[:skip_files]
    end

    def index
      prepare

      @setup[:files_to_process].each do |fpath|
        fpath_relative = fpath
        fpath = File.join(@setup[:scores_dir], fpath)

        file_modified = File.mtime(fpath)
        oldest_indexed_time = Chant.min(:created, :conditions => ['src_path = ?', fpath_relative])
        if oldest_indexed_time and oldest_indexed_time >= file_modified then
          @logger.error "#{fpath_relative} skipped: not modified"
          next
        end

        begin
          music = LilyPondMusic.new fpath
          counter = 0
          music.scores.each do |score|
            counter += 1
            quid = score.header['quid']
            if quid == nil then
              @logger.error "Score with text '#{score.lyrics_readable}' skipped: type unspecified."
              next
            end

            if quid_to_chant_type(quid) == :other then
              @logger.error "Score with text '#{score.lyrics_readable}' skipped: type irrelevant for E-antifonar."
              next
            end

            ofn = score_unique_img_fname(fpath, score)
            ofpath = File.join(@setup[:output_dir], ofn)
            oimgpath = ofpath.sub(/\.ly$/, '.png')

            chants = score_to_chant(
              score, fpath_relative,
              File.join(EAntifonar::CONFIG.chants_path, File.basename(oimgpath))
            )

            unless @indexing_strategy.to_save?(chants.first)
              @logger.error "#{chants.first.src_path}##{chants.first.score_id} already up to date."
              next
            end

            # create temporary compilable file with just the single score
            File.open(ofpath, 'w') do |fw|
              fw.puts @prepend
              fw.puts score.text
            end

            # compile, crop, copy to the data directory
            begin
              lilypond ofpath
              crop_image oimgpath
              FileUtils.mv oimgpath, EAntifonar::CONFIG.chants_path

              chants.each do |chant|
                @indexing_strategy.save_chant(chant, @logger)
              end
            rescue ExternalCommandFailedException => ex
              @logger.error ex.message
              @logger.error "Score with text '#{score.lyrics_readable}' skipped due to a compilation error (see above)."
            end
          end

        rescue => ex
          # unexpected error
          @logger.error "#{File.basename(fpath)}: processing failed in an unexpected way."
          @logger.error ex.message
          @logger.error ex.backtrace.join "\n"
        end
      end
    end

    def generate_psalm_tones
      prepare

      # Simplified process without database access
      # the psalm tones are easily found by file name
      fpath = File.join(@setup[:scores_dir], 'psalmodie.ly')
      music = LilyPondMusic.new fpath
      music.scores.each do |score|
        ofn = score_unique_img_fname(fpath, score)
        ofpath = File.join(@setup[:output_dir], ofn)
        oimgpath = ofpath.sub(/\.ly$/, '.png')

        # create temporary compilable file with just the single score
        File.open(ofpath, 'w') do |fw|
          fw.puts @prepend
          fw.puts score.text
        end

        begin
          lilypond ofpath
          crop_image oimgpath
          FileUtils.mv oimgpath, EAntifonar::CONFIG.chants_path
        rescue ExternalCommandFailedException => ex
          @logger.error ex.message
        end
      end
    end



    def lilypond(lypath)
      execute_cmd "lilypond --png -dresolution=100 #{lypath}"
    end

    def crop_image(imgpath)
      execute_cmd "mogrify -trim -transparent white #{imgpath}"
    end

    # runs command, on success returns it's output like backticks,
    # on fail raises ExternalCommandFailedException with a verbose message
    def execute_cmd(cmd)
      stdout, stderr, status = Open3.capture3 cmd
      if status != 0 then
        msg = "Command '#{cmd}' failed (#{status})"
        if stderr.size > 0 then
          msg += ":\n#{stderr}"
        elsif stdout.size > 0 then
          msg += ":\n#{stdout}"
        end
        raise ExternalCommandFailedException.new msg
      end
      return stdout
    end

    class ExternalCommandFailedException < RuntimeError
    end



    # returns a unique file name for a score;
    # fpath is path to the file where the score originally resided
    def score_unique_img_fname(fpath, score)
      score_img_id = score.header['id']
      if score_img_id == nil or score_img_id == '' then
        score_img_id = score.number.to_s
        @logger.warn "Score with text '#{score.lyrics_readable}' has no id. Position in ly file (#{score_img_id}) used."
      end
      score_img_id.gsub!(/\s+/, '_')
      return File.basename(fpath).sub(/(\.ly)$/) {|m| '_'+score_img_id+$1 }
    end

    # strips lyrics of characters that would make machine search uncomfortable
    def normalized_lyrics(score)
      if quid_to_chant_type(score.header['quid']) == :resp then
        # here we can't use lyrics_readable - we need the variables preserved
        begin
          return LyricTools.normalize_responsory score.lyrics_raw.gsub(/\s+--\s+/, '')
        rescue ArgumentError
          # Lyrics of this responsory aren't well structured.
          # Let's move on and return at least regularly normalized Lyrics.
          sample_max_len = 20
          lyr_sample = score.lyrics_readable
          if lyr_sample.size > sample_max_len then
            lyr_sample = lyr_sample[0..20]
          end
          @logger.error "Lyrics of responsory beginning with '#{lyr_sample}' aren't well structured. Fallback to non-responsory normalization."
        end
      end

      return LyricTools.normalize score.lyrics_readable
    end

    # make Chant(s) out of the LilyPondScore
    def score_to_chant(score, src_path, image_path)
      # make a database entry
      quid = (score.header['quid'] or '')
      type = quid_to_chant_type quid

      lyrics_cleaned = normalized_lyrics score

      # for some scores more variants of the lyrics are indexed:
      ls = [ lyrics_cleaned ]
      # antiphons with seasonally appended alleluia
      if type == :ant and score.text.include? '\rubrVelikAleluja' then
        alleluia_re = /\s*[Aa]leluja$/
        ls << lyrics_cleaned.sub(alleluia_re, '')
      end

      return ls.collect do |l|
        Chant.new(
          :lyrics_cleaned => l,

          :lyrics => score.lyrics_readable,
          :chant_type => type,
          :image_path => image_path,
          :header => score.header,
          :src => score.text,

          :src_path => src_path,
          :score_id => score.header['id']
        )
      end
    end

    def quid_to_chant_type(quid)
      if quid.include? 'ant.' then
        return :ant
      elsif quid.include? 'resp.' then
        return :resp
      else
        return :other
      end
    end

    private

    def load_config(fpath)
      unless FileTest.file?(fpath)
        STDERR.puts "Config '#{fpath}' not found."
        return {}
      end

      cfg = YAML.load(File.read(fpath))
      cfg2 = {}
      cfg.each_pair do |k,v|
        if k.is_a? String then
          k = k.to_sym
        end
        cfg2[k] = v
      end

      return cfg2
    end
  end # class Indexer
end # module


if $0 == __FILE__ then
  EAntifonar.init_logging
  logger = Log4r::Logger['indexing']

  options = {}

  optparse = OptionParser.new do |opts|

    opts.banner = "indexer.rb [options] SCORES_ROOT_DIR [file1 file2 ...]"
    opts.separator ""
    opts.separator "If a list of files is specified, only these will be reindexed."
    opts.separator ""

    opts.separator "Options"

    opts.on "-R", "--reindex", "Purge database content and reindex completely" do |out|
      options[:mode] = :reindex
    end

    opts.on "-n", "--no-indexing", "Skip indexing (useful if you only want to generate psalm tones)" do |out|
      options[:skip_indexing] = true
    end

    opts.on "-t", "--tones", "Generate psalm tones" do |out|
      options[:psalmtones] = true
    end

    opts.on "-h", "--help", "Print this help and exit" do
      puts opts
      exit 0
    end
  end

  optparse.parse!

  options[:scores_dir] = ARGV.shift
  if ARGV.size > 0 then
    options[:files_to_process] = ARGV
  end

  begin
    indexer = EAntifonar::Indexer.new options, logger
  rescue => ex
    raise unless ex.is_a? RuntimeError

    logger.fatal "Error during start: "+ex.message
    exit 1
  end

  indexer.index unless options[:skip_indexing]

  if options[:psalmtones] then
    indexer.generate_psalm_tones
  end
end

