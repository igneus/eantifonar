require_relative 'spec_helper.rb'
require 'ostruct'

describe EAntifonar::Indexer do

  before :each do
    @indexer = EAntifonar::Indexer.new(:scores_dir => '.')
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
      score = OpenStruct.new({:lyrics_cleaned => 'Dobrý den, dobrý den, bába letí komínem.'})
      @indexer.normalized_lyrics(score).should eq 'Dobrý den dobrý den bába letí komínem'
    end

    it 'removes redundant whitespace' do
      score = OpenStruct.new({:lyrics_cleaned => "  Dobrý  \tden \n\n "})
      @indexer.normalized_lyrics(score).should eq 'Dobrý den'
    end

    it 'removes asterisks' do
      score = OpenStruct.new({:lyrics_cleaned => "Dobrý * den"})
      @indexer.normalized_lyrics(score).should eq 'Dobrý den'
    end
  end
end