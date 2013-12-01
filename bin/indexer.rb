#!/bin/env ruby

# a script intended to be executed from the command line or by cron.
#
# fetches current data from the In adiutorium github repo,
# compiles all chants to separate png images and indexes them in a database.

require 'data_mapper'

db_path = File.expand_path('chants.sqlite3', File.join(File.dirname(__FILE__), '..', 'db'))
eantifonar_chants_path = File.expand_path('chants', File.join(File.dirname(__FILE__), '..', 'public'))

DataMapper.setup(:default, 'sqlite://'+db_path)

# load db model definition
require_relative '../lib/eantifonar/chantindex_model'

# drop all data, refresh tables according to the model
DataMapper.auto_migrate!
DataMapper.auto_upgrade!

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

require_relative '../lib/lilytools/musicreader.rb'
require_relative '../lib/lilytools/splitscores.rb'
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
      if quid == nil or not (quid.include?('ant.') or quid.include?('resp.')) then
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
      `mogrify -trim #{oimgpath}`

      # ... copy it to the eantifonar data directory
      FileUtils.mv oimgpath, eantifonar_chants_path

      # make a database entry
      type = :other
      if ['Magnificat', 'Benedictus', 'Nunc dimittis'].find {|k| quid.include? k } then
        type = :ant_gospel
      elsif quid.include? 'ant.' then
        type = :ant
      elsif quid.include? 'resp.' then
        type = :resp
      end
      chant = Chant.new(
        :chant_type => type,
        :lyrics => score.lyrics_readable,
        :lyrics_cleaned => score.lyrics_readable, # TODO clean the lyrics
        :image_path => File.join(eantifonar_chants_path, File.basename(oimgpath)),
        :src => score.text
      )
      chant.save
    end
  rescue
    STDERR.puts "file #{fn}: processing failed"
  end
end
