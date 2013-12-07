DataMapper.setup(:default, 'sqlite://' + EAntifonar::CONFIG.db_path)

# load db model definition
require_relative 'chantindex_model'

DataMapper.finalize