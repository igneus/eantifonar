#!/bin/env ruby

# a script intended to be executed from the command line or by cron.
#
# fetches current data from the In adiutorium github repo,
# compiles all chants to separate png images and indexes them in a database.

require 'data_mapper'
require_relative '../lib/eantifonar/chantindex_model'

db_path = File.expand_path('chants.sqlite3', File.dirname(__FILE__)+'/../db')

DataMapper.setup(:default, 'sqlite://'+db_path)
