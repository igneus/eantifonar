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

  describe '::responsory_unique_parts' do

    it 'returns whole response and verse' do
      l = "\\Response Kriste, Synu živého Boha, *
      smiluj se nad námi.
      \\Verse Ty, který sedíš po pravici Otce, *
      \\Response smiluj se nad námi.
      \\textRespDoxologie"
      @lt.responsory_unique_parts(l).should eq "Kriste, Synu živého Boha, * smiluj se nad námi. Ty, který sedíš po pravici Otce, *"
    end

    it 'throws ArgumentError if the responsory is not well structured' do
      l = "\\Response Kriste, Synu živého Boha, *
      smiluj se nad námi.
      Ty, který sedíš po pravici Otce, * smiluj se nad námi."
      expect do
        @lt.responsory_unique_parts(l)
      end.to raise_exception ArgumentError
    end
  end
end
