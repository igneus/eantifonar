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
end