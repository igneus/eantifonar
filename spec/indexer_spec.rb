require_relative 'spec_helper.rb'
require 'ostruct'

class MockLogger
  def initialize
    @all_logs = []
    @named_logs = {}
  end

  attr_reader :all_logs, :named_logs

  # mocks logger's logging methods
  def method_missing(method_sym, str)
    @all_logs << str
    @named_logs[method_sym] ||= []
    @named_logs[method_sym] << str
  end
end

describe EAntifonar::Indexer do

  before :each do
    @logger = MockLogger.new
    @indexer = EAntifonar::Indexer.new({:scores_dir => '.'}, @logger)
  end

  describe '#score_unique_img_fname' do

    it 'makes score fname from fname and score id' do
      score = OpenStruct.new({:header => {'id' => 'someid'}, :number => 2})
      @indexer.score_unique_img_fname('music.ly', score).should eq 'music_someid.ly'
    end

    it 'makes score fname from fname and number if id is empty' do
      score = OpenStruct.new({:header => {'id' => ''}, :number => 2})
      @indexer.score_unique_img_fname('music.ly', score).should eq 'music_2.ly'
    end

    it 'makes score fname from fname and number if id is not there' do
      score = OpenStruct.new({:header => {}, :number => 2})
      @indexer.score_unique_img_fname('music.ly', score).should eq 'music_2.ly'
    end
  end

  describe '#normalized_lyrics' do

    it 'removes interpunction' do
      score = OpenStruct.new({:lyrics_readable => 'Dobrý den, dobrý den, bába letí komínem.', :header => {'quid' => 'ant.'}})
      @indexer.normalized_lyrics(score).should eq 'Dobrý den dobrý den bába letí komínem'
    end

    it 'removes redundant whitespace' do
      score = OpenStruct.new({:lyrics_readable => "  Dobrý  \tden \n\n ", :header => {'quid' => 'ant.'}})
      @indexer.normalized_lyrics(score).should eq 'Dobrý den'
    end

    it 'removes asterisks' do
      score = OpenStruct.new({:lyrics_readable => "Dobrý * den", :header => {'quid' => 'ant.'}})
      @indexer.normalized_lyrics(score).should eq 'Dobrý den'
    end

    it 'returns unique parts only for responsories' do
      # real-life responsory - from the psalter cycle
      src = '\score {
        \relative c\' {
          \choralniRezim

          \neviditelna f
          f4 f f f f g( f) g( a) a( g) \barMax g( f d) f g g f f \barFinalis
          \neviditelna a
          a a a a a( bes) a( g) g( a) a( g) \barMax
          \neviditelna g
          g( f d) f g g f f \barFinalis
        }
        \addlyrics {
          \Response Po -- žeh -- na -- ný je Hos -- po -- din_* od vě -- ků na vě -- ky.
          \Verse Je -- nom on sám ko -- ná di -- vy_*
          \Response od vě -- ků na vě -- ky.
          \textRespDoxologie
        }
        \header {
          quid = "resp."
          modus = "VI"
          id = "1po-rch"
          piece = \markup\sestavTitulekResp
        }
      }'
      score = LilyPondScore.new src
      @indexer.normalized_lyrics(score).should eq 'Požehnaný je Hospodin od věků na věky Jenom on sám koná divy'
    end

    it 'fallbacks to standard normalized lyrics and logs error if responsory lyrics are not well structured' do
      l_raw = "Kris -- te, Sy -- nu ži -- vé -- ho Bo -- ha,_*
      smi -- luj se nad ná -- mi.
      Ty, kte -- rý se -- díš po pra -- vi -- ci Ot -- ce,_*
      smi -- luj se nad ná -- mi."
      l_readable = "Kriste, Synu živého Boha, *
      smiluj se nad námi.
      Ty, který sedíš po pravici Otce, *
      smiluj se nad námi."
      score = OpenStruct.new({:lyrics_raw => l_raw, :lyrics_readable => l_readable, :header => {'quid' => 'resp.'}})

      @indexer.normalized_lyrics(score).should eq LyricTools::normalize(score.lyrics_readable)
      @logger.named_logs[:error].size.should eq 1
    end
  end
end