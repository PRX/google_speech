# GoogleSpeech

This is a gem to call the google speech api.

The gem expects pcm wav audio.

It returns JSON including confidence values, and timing (acts as amkind of transcription alignment).

It uses excon for the http communication, sox (http://sox.sourceforge.net/) for audio conversion and splitting, and the related soxi executable to get audio file info/length.

Inspired by https://github.com/taf2/speech2text

## Installation

Add this line to your application's Gemfile:

    gem 'google_speech'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install google_speech

## Usage

As a gem in yourt code:


	require 'google_speech'
	
	f = File.open '/Users/you/Downloads/audio.wav'
  	transcriber = GoogleSpeech::Transcriber.new(f)
  	t = transcriber.transcribe

As a command line tool

	> google_speech somefile.wav

Options:
* language - what language is the speech in
* chunk_duration - length in seconds for each audio chunk of the wav to send
* overlap - chunking does not respect word boundaries; overlap can compensate
* max_results - # of results to request of speech api
* request_pause - sleep seconds between chunk transcription requests
* profanity_filter - google by default filters profanity; this gem does not.

Default option values:

	{
		:language         => 'en-US',
		:chunk_duration   => 8,
		:overlap          => 1,
		:max_results      => 2,
		:request_pause    => 1,
		:profanity_filter => false
	}

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
