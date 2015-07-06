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
      @page = EBreviarPage.new doc

      # log title of the day + hour
      hour_heading = doc.css('h2').children.collect {|h2| h2.text.strip }.select {|h2| h2 != '' }.join(' : ')
      begin
        hour_heading += ' : ' + doc.xpath("//a[@name='POPIS']/following::center[1]").text.strip.downcase
      rescue
        # hour title not found - doesn't matter
      end
      @logger.info "Decorating: "+hour_heading

      add_title hour_heading
      add_css doc
      add_js doc
      add_menu doc
      add_footer_notice doc, request_path

      chants_inserted = {} # keeps track of inserted chants to avoid useless repetition

      # tag antiphons
      @page.each_antiphon do |a1,a2,psalms|
        decorate_antiphon a1, chants_inserted, true
        decorate_antiphon a2, chants_inserted, false, psalms.size
      end

      resp = @page.responsory
      if resp then
        decorate_responsory resp
      end

      return doc
    end

    def decorate_antiphon(node, chants_inserted={}, first_antiphon_occurrence=true, num_psalms=1)
      ant_text = LyricTools.normalize @page.antiphon_text(node)
      @logger.info ant_text

      if chants_inserted.has_key? ant_text then
        chants = [ chants_inserted[ant_text] ]
      else
        chants = Chant.all(:lyrics_cleaned => ant_text, :chant_type => :ant)
      end

      ant = Nokogiri::XML::Node.new('div', node.document)
      ant['class'] = 'eantifonar-antifona'
      ant.add_child node.dup # the original <p> containing the antiphon text

      # insert the decorated antiphon in the document
      node.replace ant

      if chants.size == 0 then
        @logger.error "Chant not found for ant. '#{ant_text}'."
        return
      end

      chant = chants.first # select one from a possibly larger set

      # insert antiphon score
      if first_antiphon_occurrence or num_psalms > 1 then
        ant.add_child(chant_annotation(chant))
        ant.add_child(chant_score(chant))
      end

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
      resp_text = @page.responsory_short_text node
      resp_text = LyricTools.normalize resp_text

      chants = Chant.all(:lyrics_cleaned => resp_text, :chant_type => :resp)

      resp = Nokogiri::XML::Node.new('div', node.document)
      resp['class'] = 'eantifonar-responsorium'
      resp.add_child node.dup # the original <div> containing the responsory text

      # insert the decorated responsory in the document
      node.replace resp

      if chants.size > 0 then
        chant = chants.first # select one from a possibly larger set
        resp.add_child chant_annotation(chant)
        resp.add_child chant_score(chant)
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
      return "<div class=\"eantifonar-chant-annotation\">#{chant.annotation}</div>"
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

    def add_title(title)
      @page.title.content = title + ' @ E-antifonář'
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