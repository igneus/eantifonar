require_relative 'spec_helper'

describe EAntifonar::LyricTools do

  before :each do
    @lt = EAntifonar::LyricTools
  end

  describe '::normalize' do

    it 'removes interpunction' do
      l = 'Dobrý den, dobrý den, bába letí komínem.'
      @lt.normalize(l).should eq 'Dobrý den dobrý den bába letí komínem'
    end

    it 'removes redundant whitespace' do
      l = "  Dobrý  \tden \n\n "
      @lt.normalize(l).should eq 'Dobrý den'
    end

    it 'removes asterisks' do
      l = "Dobrý * den"
      @lt.normalize(l).should eq 'Dobrý den'
    end

    it 'removes non-breaking space' do
      l = "Dobrý\u00a0den"
      @lt.normalize(l).should eq 'Dobrý den'
    end
  end
end
