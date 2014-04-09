require_relative 'spec_helper'

require_relative '../lib/eantifonar/ebreviarpage'

require 'net/http'
require 'nokogiri'

def retrieve_doc(url)
  raw = Net::HTTP.get(URI.parse(url))
  return Nokogiri::HTML(raw)
end

describe EAntifonar::EBreviarPage do

  # known hours of a known day
  describe '2014-02-18, vespers' do
    before :all do
      @doc = retrieve_doc 'http://breviar.sk/cgi-bin/l.cgi?qt=pdt&d=18&m=2&r=2014&p=mv&j=cz&c=cz'

      @page = EAntifonar::EBreviarPage.new @doc
    end

    it 'exposes title' do
      title = @page.title
      title.should be_a Nokogiri::XML::Element
      title.text.should include 'Liturgie hodin'
    end

    it 'finds four unique antiphons' do
      ants = @page.antiphons
      ants.size.should eq 4
      ants.first.text.should include "Nemůžete sloužit"
    end

    it 'provides a helper method to access antiphon text' do
      ants = @page.antiphons
      expect(@page.antiphon_text ants.last).to eq 'Učiň s námi veliké věci, Hospodine, neboť jsi mocný a tvé jméno je svaté!'
    end

    it 'finds four separate "psalms"' do
      psalms = @page.psalms
      psalms.size.should eq 4
      psalms.first.size.should eq 1
      psalms.first.first.should be_a Nokogiri::XML::Element
      psalms.first.first.text.should include "Slyšte to"
    end

    it 'exposes responsory' do
      resp = @page.responsory
      resp.text.should include "Ukážeš mi"
    end

    it 'provides a helper method to access responsory text' do
      resp = @page.responsory
      @page.responsory_text(resp).should eq 'Ukážeš mi cestu k životu, Hospodine, * u tebe je hojná radost. Ukážeš. Po tvé pravici je věčná slast, * u tebe je hojná radost. Sláva Otci. Ukážeš.'
    end
  end

  # a subset of examples must work with any day - also today
  describe 'today' do

  end

  # also pages containing something else than a LotH hour are viewed
  describe 'not an hour' do

  end
end
