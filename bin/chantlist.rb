#!/bin/env ruby

# simply prints a sorted list of all chants in the database

require 'data_mapper'
require_relative '../lib/eantifonar/config'
require_relative '../lib/eantifonar/db_setup'

Chant.all(:order => [:chant_type, :lyrics_cleaned]).each do |chant|
  puts "#{chant.chant_type} | #{chant.lyrics_cleaned}"
end
