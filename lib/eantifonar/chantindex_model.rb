# database model of the index of chants

class Chant

  include DataMapper::Resource

  property :id, Serial

  property :chant_type, Enum[:ant, :ant_gospel, :resp, :common, :other]
  property :lyrics, String, :length => 255
  property :lyrics_cleaned, String, :length => 255 # lyrics without additional markup
  property :image_path, String, :length => 255

  property :src, Text # LilyPond source of the score
end
