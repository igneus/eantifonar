require_relative 'spec_helper'

require_relative '../lib/eantifonar/ebreviarpage'

require 'net/http'
require 'nokogiri'

def retrieve_doc(url)
  raw = Net::HTTP.get(URI.parse(url))
  return Nokogiri::HTML(raw)
end

shared_examples 'any vespers page' do
  it 'exposes title' do
    title = @page.title
    title.should be_a Nokogiri::XML::Element
    title.text.should include 'Liturgie hodin'
  end

  it 'finds four unique antiphons' do
    ants = @page.antiphons
    ants.size.should eq 4
  end

  it 'finds four separate "psalms"' do
    psalms = @page.psalms
    psalms.size.should eq 4
    psalms.first.size.should eq 1
    psalms.first.first.should be_a Nokogiri::XML::Element
  end

  it 'exposes responsory' do
    @page.responsory.should be_a Nokogiri::XML::Element
  end
end

describe EAntifonar::EBreviarPage do

  # known hours of a known day
  describe '2014-02-18, vespers' do

    it_behaves_like 'any vespers page'

    before :all do
      @doc = retrieve_doc 'http://breviar.sk/cgi-bin/l.cgi?qt=pdt&d=18&m=2&r=2014&p=mv&j=cz&c=cz'

      @page = EAntifonar::EBreviarPage.new @doc, true
    end

    it 'provides a helper method to access antiphon text' do
      ants = @page.antiphons
      expect(@page.antiphon_text ants.last).to eq 'Učiň s námi veliké věci, Hospodine, neboť jsi mocný a tvé jméno je svaté!'
    end

    it 'finds the expected antiphon' do
      @page.antiphons.first.text.should include "Nemůžete sloužit"
    end

    it 'finds the expected psalm' do
      @page.psalms.first.first.text.should include "Slyšte to"
    end

    it 'finds the expected responsory' do
      @page.responsory.text.should include "Ukážeš mi"
    end

    it 'provides a helper method to access responsory text' do
      resp = @page.responsory
      @page.responsory_text(resp).should eq 'Ukážeš mi cestu k životu, Hospodine, * u tebe je hojná radost. Ukážeš. Po tvé pravici je věčná slast, * u tebe je hojná radost. Sláva Otci. Ukážeš.'
    end

    it 'provides a helper method to access simplified responsory text' do
      resp = @page.responsory
      @page.responsory_short_text(resp).should eq 'Ukážeš mi cestu k životu, Hospodine, u tebe je hojná radost. Po tvé pravici je věčná slast,'
    end
  end

  # these vespers are a bit different from those above
  describe '2014-04-09, vespers' do
    it_behaves_like 'any vespers page'

    before :all do
      @doc = retrieve_doc 'http://breviar.sk/cgi-bin/l.cgi?qt=pdt&d=9&m=4&r=2014&p=mv&j=cz&c=cz'

      @page = EAntifonar::EBreviarPage.new @doc, true
    end
  end

  # a subset of examples must work with any day - also today
  describe 'today, vespers' do
    it_behaves_like 'any vespers page'

    before :all do
      today = Date.today
      @doc = retrieve_doc 'http://breviar.sk/cgi-bin/l.cgi?qt=pdt&d=%i&m=%i&r=%i&p=mv&j=cz&c=cz' % [today.day, today.month, today.year]

      @page = EAntifonar::EBreviarPage.new @doc, true
    end
  end

  # also pages containing something else than a LotH hour are viewed
  describe 'not an hour' do
    # TODO
  end
end
