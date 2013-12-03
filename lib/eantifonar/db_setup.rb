require 'ostruct'

module EAntifonar

  CONFIG = OpenStruct.new(
    :db_path => File.expand_path('chants.sqlite3', File.join(File.dirname(__FILE__), '..', '..', 'db')),
    :chants_path => File.expand_path('chants', File.join(File.dirname(__FILE__), '..', '..', 'public'))
  )
end

DataMapper.setup(:default, 'sqlite://' + EAntifonar::CONFIG.db_path)

# load db model definition
require_relative 'chantindex_model'

DataMapper.finalize