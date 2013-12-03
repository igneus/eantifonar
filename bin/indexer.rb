#!/bin/env ruby

# a script intended to be executed from the command line or by cron.
#
# fetches current data from the In adiutorium github repo,
# compiles all chants to separate png images and indexes them in a database.

require 'data_mapper'
require_relative '../lib/eantifonar/db_setup'

# drop all data, refresh tables according to the model
DataMapper.auto_migrate!
DataMapper.auto_upgrade!

DataMapper::Model.raise_on_save_failure = true

# prepare scores
scores_dir = ARGV.shift
if scores_dir == nil then
  STDERR.puts "Program expects an argument: path to a directory with scores."
  exit 1
end

output_dir = File.join(scores_dir, 'eantifonar_tmp')
unless File.exist? output_dir
  Dir.mkdir output_dir
end
`rm -rf #{output_dir}/*`

require_relative '../lib/lilytools/musicreader.rb'
require 'fileutils'

# where to look for scores in the In adiutorium project structure -
scores_subdirs = ['.', 'antifony', 'commune', 'sanktoral']

# for now just a simple example
scores_files = [ 'kompletar.ly' ]

prepend = '\include "../spolecne.ly"'+"\n"+'\include "../dilyresponsorii.ly"'+"\n" # includes
prepend += '\header { tagline = "" }'+"\n" # reset tagline for easier image trimming

Dir.chdir output_dir # because we will execute programs expecting this

scores_files.each do |fn|
  fpath = File.join(scores_dir, fn)
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

      # create temporary compilable file with just the single score
      ofn = File.basename(fn).sub(/(\.ly)$/) {|m| '_'+counter.to_s+$1 }
      ofpath = File.join(output_dir, ofn)
      File.open(ofpath, 'w') do |fw|
        fw.puts prepend
        fw.puts score.text
      end

      # process it by LilyPond,
      `lilypond --png #{ofpath}`

      # ... crop the image by ImageMagick
      oimgpath = ofpath.sub(/\.ly$/, '.png')
      `mogrify -trim -transparent white #{oimgpath}`

      # ... copy it to the eantifonar data directory
      FileUtils.mv oimgpath, EAntifonar::CONFIG.chants_path

      # make a database entry
      type = :other
      if ['Magnificat', 'Benedictus', 'Nunc dimittis'].find {|k| quid.include? k } then
        type = :ant_gospel
      elsif quid.include? 'ant.' then
        type = :ant
      elsif quid.include? 'resp.' then
        type = :resp
      end

      lyrics_cleaned = score.lyrics_readable.gsub(/\s*\*\s*/, ' ')
      chant = Chant.new(
        :chant_type => type,
        :lyrics => score.lyrics_readable,
        :lyrics_cleaned => lyrics_cleaned,
        :image_path => File.join(EAntifonar::CONFIG.chants_path, File.basename(oimgpath)),
        :src => score.text
      )
      unless chant.valid?
        STDERR.puts "warning: object invalid"
        p chant
      end
      chant.save
    end
  rescue => ex
    STDERR.puts "#{fn}: processing failed"
    STDERR.puts
    STDERR.puts ex.message
    STDERR.puts ex.backtrace.join "\n"
    STDERR.puts
  end
end
