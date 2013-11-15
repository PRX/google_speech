# -*- encoding: utf-8 -*-

require 'excon'
require 'json'

module GoogleSpeech

  class Transcriber
    attr_accessor :original_file, :options, :results

    DEFAULT_OPTIONS =   {
      :language         => 'en-US',
      :chunk_duration   => 5,
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
        next unless transcript

        result = result.merge(extract_result(transcript))

        logger.debug "#{result[:start_time]}: #{(result[:confidence].to_f * 100).to_i}%: #{result[:text]}"

        @results << result

        sleep(options[:request_pause].to_i)
      }
      @results
    end

    def extract_result(transcripts)
      results = transcripts.map{|t| result_from_transcript(t)}.compact

      return {:text => '', :confidence => 0} if results.size == 0

      t = results.collect {|t| t[:text] }.join(' ')
      c = results.inject(0.0) {|s, t| s.to_f + t[:confidence].to_f } / results.size.to_f
      c = 0 if c.nan? || c.infinite?

      { :text => t, :confidence => c }
    end

    def result_from_transcript(transcript)
      hyp = transcript['hypotheses'].first
      hyp ? { :text => hyp['utterance'], :confidence => hyp['confidence'] } : nil
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
        # puts "response: #{response.inspect}\n\n"
        # puts "response.body: #{response.body}\n\n"
        if response.status.to_s.start_with?('2')
          if (response.body && response.body.size > 0)
            result = response.body.split("\n").collect{|b| JSON.parse(b)}
            # puts "results #{result.count}: #{result.inspect}\n\n"
          end
        else
          sleep(1)
          retry_count += 1
        end
      end

      result
    end

    def logger
      GoogleSpeech::Utility.logger
    end

  end
end
