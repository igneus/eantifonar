module EAntifonar

  # decorates HTML documents - pages from ebreviar.cz - adding chants
  class Decorator

    # accepts a Nokogiri html document; modifies it directly
    def decorate(doc)

      # tag antiphons
      doc.css('p > b > span.red').each do |span|
        if span.text.downcase.include? 'ant.' then
          p = span.parent.parent
          decorate_antiphon p
        end
      end

      return doc
    end

    def decorate_antiphon(node)
      #node['class'] = 'eantifonar-antifona'
      ant_text = node.css('b').text # text together with the leading rubric

      # try to get pure antiphon text
      node.css('b').children.each do |c|
        if c.is_a? Nokogiri::XML::Text and c.text.strip.size > 0 then
          ant_text = c.text.strip
          ant_text.gsub!(/\s+/, ' ') # normalize (regular) whitespace
          ant_text.gsub!("\u00a0", ' ') # utf-8 non-breaking space - nokogiri obviously converts &nbsp; entity to this character
          break
        end
      end

      chants = Chant.all(:lyrics_cleaned => ant_text)

      ant = Nokogiri::XML::Node.new('div', node.document)
      ant['class'] = 'eantifonar-antifona'
      ant.add_child node.dup # the original <p> containing the antiphon text

      if chants.size > 0 then
        chant = chants.first # select one from a possibly larger set
        ant.add_child(chant_annotation(chant))
        src = File.join('/eantifonar', 'chants', File.basename(chant.image_path))
        ant.add_child "<div class=\"eantifonar-score\"><img src=\"#{src}\"></div>"
      else
        STDERR.puts "Chant not found for ant. '#{ant_text}'."
      end

      node.swap ant
    end

    def chant_annotation(chant)
      an = ''
      if chant.header.has_key? 'modus' then
        an += chant.header['modus']
        if chant.header.has_key? 'differentia' then
          an += '.' + chant.header['differentia']
        end
      end

      return "<div class=\"eantifonar-chant-annotation\">#{an}</div>"
    end

  end # class Decorator
end