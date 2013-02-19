# -*- encoding: utf-8 -*-

require 'test_helper.rb'

describe Transcriber do
  before do
  end

  describe 'load file' do
	  f = File.open '/Users/andrew/Downloads/hive.wav'
	  # f = File.open('/Users/andrew/dev/projects/nu_wav/test/files/test_basic.wav')
	  transcriber = GoogleSpeech::Transcriber.new(f)
	  t = transcriber.transcribe
	  puts t.inspect
  end

  # describe "when asked about cheeseburgers" do
  #   it "must respond positively" do
  #     @meme.i_can_has_cheezburger?.must_equal "OHAI!"
  #   end
  # end

  # describe "when asked about blending possibilities" do
  #   it "won't say no" do
  #     @meme.will_it_blend?.wont_match /^no/i
  #   end
  # end

end