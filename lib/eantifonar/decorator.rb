# -*- coding: utf-8 -*-

module EAntifonar

  # decorates HTML documents - pages from ebreviar.cz - adding chants
  class Decorator

    # crash - in some situations prefer loud crash over graceful overcoming of an error state
    def initialize(logger, crash=false)
      @logger = logger
      @crash = crash
    end

    # accepts a Nokogiri html document; modifies it directly
    def decorate(doc, request_path)
      # log title of the day + hour
      hour_heading = doc.css('h2').children.collect {|h2| h2.text.strip }.select {|h2| h2 != '' }.join(' : ')
      begin
        hour_heading += ' : ' + doc.xpath("//a[@name='POPIS']/following::center[1]").text.strip.downcase
      rescue
        # hour title not found - doesn't matter
      end
      @logger.info "Decorating: "+hour_heading

      add_title doc, hour_heading
      add_css doc
      add_js doc
      add_menu doc
      add_footer_notice doc, request_path

      chants_inserted = {} # keeps track of inserted chants to avoid useless repetition

      # tag antiphons
      doc.css('p > b > span.red').each_with_index do |span,ant_i|
        if span.text.downcase.include? 'ant' then
          p = span.parent.parent
          decorate_antiphon p, chants_inserted
        end
      end

      doc.css('p > span.redsmall').each do |span|
        if span.text == 'ZPĚV PO KRÁTKÉM ČTENÍ' then
          p = span.parent
          decorate_responsory p
        end
      end

      return doc
    end

    def decorate_antiphon(node, chants_inserted={})
      ant_text = node.css('b').text # text together with the leading rubric

      # try to get pure antiphon text
      node.css('b').children.each do |c|
        if c.is_a? Nokogiri::XML::Text and c.text.strip.size > 0 then
          ant_text = LyricTools.normalize c.text
          break
        end
      end

      if chants_inserted.has_key? ant_text then
        chants = chants_inserted[ant_text]
      else
        chants = Chant.all(:lyrics_cleaned => ant_text, :chant_type => :ant)
      end

      ant = Nokogiri::XML::Node.new('div', node.document)
      ant['class'] = 'eantifonar-antifona'
      ant.add_child node.dup # the original <p> containing the antiphon text

      # insert the decorated antiphon in the document
      node.replace ant

      antiphon_after_single_psalm = (not (
        ant.previous_element['class'] == 'psalm' and
        ant.previous_element.previous_element['class'] == 'psalm'
      ))
      first_antiphon_occurrence = (not chants_inserted.has_key? ant_text)

      if (not first_antiphon_occurrence) and antiphon_after_single_psalm then
        return nil
      end

      if chants.size == 0 then
        @logger.error "Chant not found for ant. '#{ant_text}'."
        return
      end

      chant = chants.first # select one from a possibly larger set

      # insert antiphon score
      ant.add_child(chant_annotation(chant))
      ant.add_child(chant_score(chant))

      unless first_antiphon_occurrence
        return
      end

      chants_inserted[ant_text] = chant

      # insert psalm tone
      ps = ant.next_element
      if ps['class'].is_a? String and ps['class'].include? 'psalm' then
        insert_rel = ps.xpath('./p[1]').first
        insert = :before
      else
        # psalm not found. Let's insert the psalm tone directly after the antiphon.
        insert_rel = ant
        insert = :after
      end
      insert_rel.send insert, psalm_tone_for(chant)
    rescue => ex
      @logger.error "#{ex.class} while decorating antiphon '#{node.text}': "+ex.message
      if @crash then
        raise
      end
    end

    def decorate_responsory(node)
      r_text = node.xpath('./b[1]').first.text.sub('O.', '')
      # second last full-stop - beginning of the response indicating repetition - remove what follows
      rep_i = r_text.rindex('.', r_text.rindex('.')-1)
      r_text = r_text[0..rep_i]

      v_text = node.xpath('./b[2]').first.text.sub('V.', '')
      r2i = v_text.rindex '*' # second part of the response repeated - remove what follows
      v_text = v_text[0..r2i]

      resp_text = r_text + v_text
      resp_text = LyricTools.normalize resp_text

      chants = Chant.all(:lyrics_cleaned => resp_text, :chant_type => :resp)

      resp = Nokogiri::XML::Node.new('div', node.document)
      resp['class'] = 'eantifonar-responsorium'
      resp.add_child node.dup # the original <p> containing the antiphon text

      # insert the decorated responsory in the document
      node.replace resp

      if chants.size > 0 then
        chant = chants.first # select one from a possibly larger set
        # urgh ... title of the Gospel canticle is inside the same <p>
        # as responsory
        resp_last_verse = resp.xpath('./p/b[2]').first
        resp_last_verse.after chant_score(chant)
        resp_last_verse.after chant_annotation(chant)
      else
        @logger.error "Chant not found for resp. '#{resp_text}'."
      end
    rescue => ex
      @logger.error "#{ex.class} while decorating responsory '#{node.text}': "+ex.message
      if @crash then
        raise
      end
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

    # score HTML
    def chant_score(chant)
      src = File.join('/chants', File.basename(chant.image_path))

      lily = chant.src
      im = lily.index('\relative')
      ie = lily.index('}', im)
      lily = lily[im..ie]

      return "<div class=\"eantifonar-score\">
        <a href=\"/chant/#{chant.id}\"><img src=\"#{src}\"></a>
        <div class=\"lily\">#{lily}</div>
      </div>"
    end

    def psalm_tone_for(chant)
      modus = chant.header['modus']
      diffe = chant.header['differentia'] || ""
      t_pretty = modus + (diffe != '' ? ".#{diffe}" : '')
      t_handy = modus + (diffe != '' ? "-#{diffe}" : '')
      t_handy.gsub!(/\s+/, '_')

      return "<div class=\"eantifonar-psalm-tone\"><img src=\"/chants/psalmodie_#{t_handy}.png\" alt=\"#{t_pretty}\" /></div>"
    end

    def add_title(doc, title)
      doc.xpath('/html/head/title').first.content = title + ' @ E-antifonář'
    rescue
      # title not found in the document; doesn't matter
    end

    # inserts additional stylesheets in the head
    def add_css(doc)
      stylesheets = doc.css("head link[type='text/css']")
      return if stylesheets.empty?

      unless stylesheets.last['href'].include? 'breviar-lista.css'
        stylesheets.last.after('<link rel="stylesheet" type="text/css" href="/css/eantifonar.css" />')
      end
    end

    # inserts necessary javascripts in the head
    def add_js(doc)
      scripts = [
        '/vendor/js/jquery-2.1.0.min.js',
        '/js/chantplayer.js'
      ]
      head = doc.css('head')
      return if head.empty?
      head = head.first

      scripts.each do |s|
        head.add_child "<script src=\"#{s}\" type=\"text/javascript\"></script>"
      end

      head.add_child "<script type=\"text/javascript\">
        $(document).ready(function(){
          $('.eantifonar-score').each(function(){
            var music = $('.lily', $(this)).text();
            addChantPlayer($(this), 'click', music);
          });
        });
        </script>"
    end

    # adds our menu with links
    def add_menu(doc)
      menu_code = File.read(File.expand_path('menu.html', File.join(File.basename(__FILE__), '..', 'data', 'html')))
      doc.css('body').first.add_child(menu_code)
    end

    def add_footer_notice(doc, request_path)
      footer = doc.css('p.patka').last
      footer.after('<p class="patka">
        Nenacházíte se na e-breviáři, ale na e-antifonáři,
        který z e-breviáře stahuje texty a modifikuje je.
        Byl upraven styl stažené stránky a k některým textům vloženy noty.
        Za e-antifonář může <a href="mailto:jkb.pavlik@gmail.com">Jakub Pavlík</a>.
        </p>')
      footer.after('<p class="patka">
        <a href="'+request_path+'">Zobrazit odpovídající stránku na e-breviáři.</a>
        </p>')
    end

  end # class Decorator
end