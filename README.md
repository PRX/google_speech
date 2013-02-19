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

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
