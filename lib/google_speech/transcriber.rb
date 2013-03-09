# -*- encoding: utf-8 -*-

require 'excon'
require 'json'

module GoogleSpeech

  class Transcriber
    attr_accessor :original_file, :options, :results

    DEFAULT_OPTIONS =   {
      :language         => 'en-US',
      :chunk_duration   => 8,
      :overlap          => 1,
      :max_results      => 2,
      :request_pause    => 1,
      :profanity_filter => false
    }

    def initialize(original_file, options=nil)
      @original_file = original_file
      @options = DEFAULT_OPTIONS.merge(options || {})
      @results = []
    end

    def transcribe
      chunk_factory = ChunkFactory.new(@original_file, options[:chunk_duration], options[:overlap])
      chunk_factory.each{ |chunk|
        result = chunk.to_hash
        transcript = transcribe_data(chunk.data)
        hypothesis = transcript['hypotheses'].first || Hash.new("")
        result[:text]       = hypothesis['utterance']
        result[:confidence] = hypothesis['confidence']
        @results << result

        # puts "\n#{result[:start_time]} - #{result[:start_time].to_i + result[:duration].to_i}: #{(result[:confidence].to_f * 100).to_i}%: #{result[:text]}"

        sleep(options[:request_pause].to_i)
      }
      @results
    end

    def pfilter
      options[:profanity_filter] ? '1' : '0'
    end

    def transcribe_data(data)
      params = {
        :scheme   => 'https',
        :host     => 'www.google.com',
        :port     => 443,
        :path     => "/speech-api/v1/recognize",
        :query    => "xjerr=1&client=google_speech&lang=#{options[:language]}&maxresults=#{options[:max_results].to_i}&pfilter=#{pfilter}",
        :body     => data,
        :method   => 'POST',
        :headers  => {
          'Content-Type'   => 'audio/x-flac; rate=16000',
          'Content-Length' => data.bytesize,
          'User-Agent'     => "google_speech"
        }
      }
      retry_max = options[:retry_max] ? [options[:retry_max].to_i, 1].max : 3
      retry_count = 0
      result = nil
      url = "#{params[:scheme]}://#{params[:host]}:#{params[:port]}#{params[:path]}"
      while(!result && retry_count < retry_max)
        connection = Excon.new(url)
        response = connection.request(params)
        if response.status.to_s.start_with?('2')
          result = JSON.parse(response.body)          
        else
          sleep(1)
          retry_count += 1
        end
      end

      result
    end

  end

end
