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

      def normalize_responsory(lyrics)
        normalize responsory_unique_parts lyrics
      end

      # takes responsory lyrics including variables used in the In adiutorium project:
      # \Response, \Verse, \textRespDoxologie
      # returns just text unique to the particular responsory and without repetition,
      # i.e. the whole response and verse
      def responsory_unique_parts(lyrics)
        unless lyrics.count("\\") >= 2
          raise ArgumentError, "Text isn't well structured. \\Response and \\Verse part expected."
        end

        parts = lyrics.split("\\").select {|part| part.strip.include?(' ') }.collect do |part|
          first_word_end = part.index ' '
          # [part name, text]
          [ part[0..first_word_end], part[first_word_end..-1].strip ]
        end

        return (parts[0][1] + ' ' + parts[1][1])
          .gsub(/\s+/, ' ')
      end
    end
  end
end