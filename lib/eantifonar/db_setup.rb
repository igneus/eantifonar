db_path = File.expand_path('chants.sqlite3', File.join(File.dirname(__FILE__), '..', '..', 'db'))
eantifonar_chants_path = File.expand_path('chants', File.join(File.dirname(__FILE__), '..', 'public'))

DataMapper.setup(:default, 'sqlite://'+db_path)

# load db model definition
require_relative 'chantindex_model'

DataMapper.finalize