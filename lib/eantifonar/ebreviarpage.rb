# encoding: UTF-8

require_relative 'lyrictools'

module EAntifonar

  # Wraps a Nokogiri::HTML document.
  # Exposes it's parts accessed and modified by our application
  # hiding most of the document structure traversal
  class EBreviarPage

    # doc - expected Nokogiri::HTML
    def initialize(doc, crash=false)
      @doc = doc
      @crash = crash
    end

    attr_reader :doc

    def title
      @doc.xpath('/html/head/title').first
    end

    def responsory
      responses = @doc.css('div.respons')

      # "Deus in adiutorium meum" has the same wrapper
      # as responsory after the short reading
      if responses.size < 2
        return nil
      end

      return responses[1]
    end

    # For each antiphon yields the first occurrence,
    # the repetition and the psalm/s wrapped.
    #
    # This is the fastest way of accessing antiphons
    # and psalms. All the methods below call each_antiphon
    # internally.
    def each_antiphon
      occurrence1 = occurrence2 = nil
      psalms = []

      ant_i = -1
      @doc.xpath("//p/span[@class='red'][1]").each do |span|
        next unless span.text.downcase.include? 'ant'

        ant_i += 1
        p = span.parent
        if ant_i % 2 == 0 then # we start with 0
          occurrence1 = p

          pre = occurrence1
          while pre.next.name == 'div' and pre.next['class'] == 'psalm'
            psalms << pre.next
            pre = pre.next
          end
        else
          occurrence2 = p

          if @crash && antiphon_text(occurrence1) != antiphon_text(occurrence2) then
            raise RuntimeError.new("A pair of non-matching antiphons found '#{occurrence1.text}', '#{occurrence2.text}'")
          end

          yield occurrence1, occurrence2, psalms

          occurrence1 = occurrence2 = nil
          psalms = []
        end
      end
    end

    # first occurrence of each antiphon
    def antiphons
      r = []
      each_antiphon {|a1| r << a1 }
      return r
    end

    # psalms / psalm groups
    def psalms
      r = []
      each_antiphon {|a1,a2,p| r << p }
      return r
    end

    # helper methods to access cleaned texts of important nodes

    def antiphon_text(ant)
      ant.children.collect do |c|
        if c.kind_of? Nokogiri::XML::Text and not c.text.strip.empty? then
          return c.text \
            .gsub("\u00a0", ' ') # replace non-breaking spaces
        end
      end

      return ''
    end

    def responsory_text(resp)
      r = []
      resp.xpath('p').each do |b|
        b.children.collect do |c|
          if (c.kind_of? Nokogiri::XML::Text and not c.text.strip.empty?) or
              (c.name == 'span' and c.text == '*') then
            r << c.text.strip \
              .gsub("\u00a0", ' ') # replace non-breaking spaces
          end
        end
      end
      return r.join(' ')
    end

    # only response + verse
    def responsory_short_text(resp)
      # this would lead to unexpected results for responsories
      # including fullstop in either response or verse.
      # TODO: check if there are any.
      full = responsory_text resp
      end_with_verse = full.split(/\s*\*\s*/)[0..1].join(' ')
      without_rep = end_with_verse.split('.')
      without_rep.delete_at 1 # remove the shortenned repetition following the response
      return without_rep.join('.')
    end
  end
end
