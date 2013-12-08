# -*- coding: utf-8 -*-

module EAntifonar

  # decorates HTML documents - pages from ebreviar.cz - adding chants
  class Decorator

    # accepts a Nokogiri html document; modifies it directly
    def decorate(doc)

      add_css doc
      add_menu doc
      add_footer_notice doc

      chants_inserted = {} # keeps track of inserted chants to avoid useless repetition

      # tag antiphons
      doc.css('p > b > span.red').each do |span|
        if span.text.downcase.include? 'ant' then
          p = span.parent.parent
          decorate_antiphon p, chants_inserted
        end
      end

      return doc
    end

    def decorate_antiphon(node, chants_inserted={})
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

      if chants_inserted.include? ant_text then
        # this is a second occurrence of an antiphon - don't repeat the score.
        return
      end

      if chants.size > 0 then
        chant = chants.first # select one from a possibly larger set
        chants_inserted[ant_text] = chant
        ant.add_child(chant_annotation(chant))
        src = File.join('/chants', File.basename(chant.image_path))
        ant.add_child "<div class=\"eantifonar-score\"><a href=\"/chant/#{chant.id}\"><img src=\"#{src}\"></a></div>"
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

    # inserts additional stylesheets in the head
    def add_css(doc)
      stylesheets = doc.css("head link[type='text/css']")
      return if stylesheets.empty?

      unless stylesheets.last['href'].include? 'breviar-lista.css'
        stylesheets.last.after('<link rel="stylesheet" type="text/css" href="/css/eantifonar.css" />')
      end
    end

    # adds our menu with links
    def add_menu(doc)
      menu_code = File.read(File.expand_path('menu.html', File.join(File.basename(__FILE__), '..', 'data', 'html')))
      doc.css('body').first.add_child(menu_code)
    end

    def add_footer_notice(doc)
      doc.css('p.patka').last.after('<p class="patka">
        Nenacházíte se na e-breviáři, ale na e-antifonáři,
        který z e-breviáře stahuje texty a modifikuje je.
        Byl upraven styl stažené stránky a k některým textům vloženy noty.
        Za e-antifonář může <a href="mailto:jkb.pavlik@gmail.com">Jakub Pavlík</a>.
        </p>')
    end

  end # class Decorator
end