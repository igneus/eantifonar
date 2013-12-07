#!/bin/env ruby

# a script intended to be executed from the command line or by cron.
#
# fetches current data from the In adiutorium github repo,
# compiles all chants to separate png images and indexes them in a database.

require 'data_mapper'
require 'fileutils'
require 'optparse'

require_relative '../lib/lilytools/musicreader.rb'
require_relative '../lib/eantifonar/config'
require_relative '../lib/eantifonar/db_setup'

DataMapper::Model.raise_on_save_failure = true

module EAntifonar

  # IndexingStrategy subclasses define a way of saving Chants
  # to the database (save always? check something before?)
  class IndexingStrategy

    # takes a Chant instance and saves it
    def save_chant(chant)
      unless chant.valid?
        STDERR.puts "warning: Chant instance invalid"
        p chant
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

    def save_chant(chant)
      unless to_save? chant
        return false
      end

      present = get_existing chant

      # the chant changed. delete the original, save the new
      if present then
        destroyed = present.destroy
        unless destroyed
          STDERR.puts "Failed to delete old record of chant #{present.src_path}##{present.score_id}"
          return false
        end
      end

      super(chant)
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

  # drop all data from the database at initialization;
  # save anything
  class ReindexIndexingStrategy < IndexingStrategy

    def initialize
      # drop all data, refresh tables according to the model
      DataMapper.auto_migrate!
      DataMapper.auto_upgrade!
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

    def initialize(setup)
      @setup = DEFAULT_SETUP.dup
      @setup.update(load_config(File.join(@setup[:app_root], @setup[:config_file])))
      @setup.update setup

      if @setup[:scores_dir] == nil then
        raise "Directory with scores not set. Nothing to do."
      elsif not File.directory? @setup[:scores_dir] then
        raise "Directory with scores '#{@setup[:scores_dir]}' does not exist."
      end

      if @setup[:output_dir] == nil then
        @setup[:output_dir] = File.join(@setup[:scores_dir], 'eantifonar_tmp')
      end

      if @setup[:files_to_process].empty? then
        @setup[:files_to_process] = @setup[:scores_subdirs].collect do |subdir|
          fullpath = File.join(@setup[:scores_dir], subdir, '*.ly')
          Dir[fullpath].collect {|f| File.join(f.split('/')[-2..-1]) } # we only want 'subdir/file.ly'
        end.flatten

        # skipping applied only when scanning the whole 'chant-base'
        skip_files = @setup[:skip_files].collect do |sf|
          unless File.basename(sf) != sf
            sf = './' + sf
          end
          fullpath = File.join(@setup[:scores_dir], sf)
          Dir[fullpath].collect {|f| f.sub @setup[:scores_dir], '' }
        end.flatten
        p skip_files
        @setup[:files_to_process] -= skip_files
      end

      indexing_strategy_name = @setup[:mode].to_s.capitalize+'IndexingStrategy'
      @indexing_strategy = EAntifonar.const_get(indexing_strategy_name).new

      # definitions prepended to each lilypond chunk to make it standalone compilable
      @prepend = File.read(File.expand_path('eantifonar_common.ly', File.join(@setup[:app_root], 'data', 'ly')))

      p @setup
    end

    def index
      unless File.directory? @setup[:output_dir]
        Dir.mkdir @setup[:output_dir]
      end

      Dir.chdir @setup[:output_dir] # because we will execute programs expecting this

      @setup[:files_to_process].each do |fpath|

        fpath_relative = fpath
        fpath = File.join(@setup[:scores_dir], fpath)

        file_modified = File.mtime(fpath)
        oldest_indexed_time = Chant.min(:created, :conditions => ['src_path = ?', fpath_relative])
        if oldest_indexed_time and oldest_indexed_time >= file_modified then
          STDERR.puts "#{fpath_relative} skipped: not modified"
          next
        end

        begin
          music = LilyPondMusic.new fpath
          counter = 0
          music.scores.each do |score|
            counter += 1
            quid = score.header['quid']
            if quid == nil then
              STDERR.puts "Score with text '#{score.lyrics_readable}' skipped: type unspecified."
              next
            end

            score_img_id = score.header['id']
            if score_img_id == nil then
              score_img_id = counter.to_s
              STDERR.puts "Score with text '#{score.lyrics_readable}' has no id. Position in ly file used."
            end

            if quid_to_chant_type(quid) == :other then
              STDERR.puts "Score with text '#{score.lyrics_readable}' skipped: type irrelevant for E-antifonar."
              next
            end

            ofn = File.basename(fpath).sub(/(\.ly)$/) {|m| '_'+score_img_id+$1 }
            ofpath = File.join(@setup[:output_dir], ofn)
            oimgpath = ofpath.sub(/\.ly$/, '.png')

            chants = score_to_chant(
              score, fpath_relative,
              File.join(EAntifonar::CONFIG.chants_path, File.basename(oimgpath))
            )

            unless @indexing_strategy.to_save?(chants.first)
              STDERR.puts "#{chants.first.src_path}##{chants.first.score_id} already up to date."
              next
            end

            # create temporary compilable file with just the single score
            File.open(ofpath, 'w') do |fw|
              fw.puts @prepend
              fw.puts score.text
            end

            # process it by LilyPond,
            `lilypond --png #{ofpath}`

            # ... crop the image by ImageMagick

            `mogrify -trim -transparent white #{oimgpath}`

            # ... copy it to the eantifonar data directory
            FileUtils.mv oimgpath, EAntifonar::CONFIG.chants_path

            chants.each do |chant|
              @indexing_strategy.save_chant(chant)
            end
          end
        rescue => ex
          STDERR.puts "#{File.basename(fpath)}: processing failed"
          STDERR.puts
          STDERR.puts ex.message
          STDERR.puts ex.backtrace.join "\n"
          STDERR.puts
        end
      end
    end

    private

    # make Chant(s) out of the LilyPondScore
    def score_to_chant(score, src_path, image_path)
      # make a database entry
      quid = (score.header['quid'] or '')
      type = quid_to_chant_type quid

      lyrics_cleaned = score.lyrics_readable.dup
      lyrics_cleaned.strip!
      lyrics_cleaned.gsub!(/\s*\*\s*/, ' ') # no asterisks

      # for some scores more variants of the lyrics are indexed:
      ls = [ lyrics_cleaned ]
      # antiphons with seasonally appended alleluia
      if type == :ant and score.text.include? '\rubrVelikAleluja' then
        alleluia_re = /\s*[Aa]leluja[\.!]$/
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
    indexer = EAntifonar::Indexer.new options
  rescue => ex
    raise unless ex.is_a? RuntimeError

    STDERR.puts "Error during start: "+ex.message
    exit 1
  end

  indexer.index
end

