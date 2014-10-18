# encoding: UTF-8

# database model of the index of chants

class Chant

  include DataMapper::Resource

  property :id, Serial
  property :created, Time

  property :chant_type, Enum[:ant, :resp, :common, :other]
  property :lyrics, String, :length => 800
  property :lyrics_cleaned, String, :length => 800 # lyrics without additional markup
  property :image_path, String, :length => 255

  property :header, Json, :lazy => false # score header (metadata) as json
  property :src, Text # LilyPond source of the score

  property :src_path, String, :length => 255 # path of the source file relative to scores root
  property :score_id, String, :length => 32 # identifier of the score unique in the source file
  property :src_name, String, :length => 255 # title of the source file or it's master file (optional)

  def initialize(*args)
    super(*args)
    self.created = Time.now
  end

  def annotation
    an = ''
    if header.has_key? 'modus' then
      an += header['modus']
      if header.has_key? 'differentia' then
        an += '.' + header['differentia']
      end
    end
    return an
  end
end
