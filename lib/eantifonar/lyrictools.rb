module EAntifonar

  # tools manipulating lyrics
  module LyricTools
    class << self

      # normalize lyrics
      # used by both the indexer and the decorator
      # to ensure as much similarity of the strings matched against each other
      # as possible
      def normalize(lyrics)
        lyrics
          .gsub(/[[:punct:]]/, '')
          .gsub("\u00a0", ' ') # non-breaking space
          .gsub(/\s+/, ' ')
          .strip
      end
    end
  end
end