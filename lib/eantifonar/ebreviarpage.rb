# encoding: UTF-8

require_relative 'lyrictools'

module EAntifonar

  # Wraps a Nokogiri::HTML document.
  # Exposes it's parts accessed and modified by our application
  # hiding most of the document structure traversal
  class EBreviarPage

    # doc - expected Nokogiri::HTML
    def initialize(doc)
      @doc = doc
    end

    attr_reader :doc

    def title
      @doc.xpath('/html/head/title').first
    end

    def responsory
      @doc.css('p > span.redsmall').each do |span|
        if span.text == 'ZPĚV PO KRÁTKÉM ČTENÍ' then
          return span.parent
        end
      end

      # nothing found
      return nil
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

      return @doc.css('p > b > span.red').each_with_index do |span,ant_i|
        if span.text.downcase.include? 'ant' then
          p = span.parent.parent
          if ant_i % 2 == 0 then # we start with 0
            occurrence1 = p

            pre = occurrence1
            while pre.next.name == 'div' and pre.next['class'] == 'psalm'
              psalms << pre.next
              pre = pre.next
            end
          else
            occurrence2 = p

            yield occurrence1, occurrence2, psalms

            occurrence1 = occurrence2 = nil
            psalms = []
          end
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
      ant.xpath('b').first.children.collect do |c|
        if c.kind_of? Nokogiri::XML::Text and not c.text.strip.empty? then
          return c.text \
            .gsub("\u00a0", ' ') # replace non-breaking spaces
        end
      end

      return ''
    end

    def responsory_text(resp)
      r = []
      resp.xpath('b').each do |b|
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
  end
end