# database model of the index of chants

class Chant

  include DataMapper::Resource

  property :id, Serial

  property :chant_type, Enum[:ant, :ant_gospel, :resp, :common, :other]
  property :lyrics, String
  property :lyrics_cleaned, String # lyrics without additional markup
  property :image_path, String

  property :src, Text # LilyPond source of the score
end

DataMapper.finalize