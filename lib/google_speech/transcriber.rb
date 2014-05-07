# -*- encoding: utf-8 -*-

require 'excon'
require 'json'

module GoogleSpeech

  class Transcriber
    attr_accessor :original_file, :options, :results

    DEFAULT_OPTIONS =   {
      :key              => 'AIzaSyCnl6MRydhw_5fLXIdASxkLJzcJh5iX0M4',
      :language         => 'en-US',
      :chunk_duration   => 5,
      :overlap          => 0.5,
      :max_results      => 1,
      :request_pause    => 1,
      :profanity_filter => true
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
      alt = transcript['result'].first['alternative'].first rescue nil
      alt ? { :text => alt['transcript'], :confidence => (alt['confidence'] || '0.9')  } : nil
    end

    def pfilter
      options[:profanity_filter] ? '1' : '0'
    end

    def transcribe_data(data)
      params = {
        :path     => "/speech-api/v2/recognize",
        :query    => "output=json&client=chromium&lang=#{options[:language]}&key=#{options[:key]}",
        :body     => data,
        :method   => 'POST',
        :headers  => {
          'Content-Type'   => 'audio/x-flac; rate=8000',
          'Content-Length' => data.bytesize,
          'User-Agent'     => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1664.3 Safari/537.36"
        }
      }
      retry_max = options[:retry_max] ? [options[:retry_max].to_i, 1].max : 3
      retry_count = 0
      result = nil
      url = "https://www.google.com:443#{params[:path]}"
      while(!result && retry_count < retry_max)
        retry_count += 1

        begin
          connection = Excon.new(url)
          response = connection.request(params)
          # puts "response: #{response.inspect}\n\n"
          # puts "response.body:\nSTART\n#{response.body}\nEND\n#{response.body.class.name}"
          if response.status.to_s.start_with?('2')
            result = []
            if (response.body && response.body.size > 0)
              result = response.body.split("\n").collect{|b| JSON.parse(b)} rescue []
            end
          else
            logger.error "transcribe_data response unsuccessful, status: #{response.status}, response: #{response.inspect}"
            sleep(1) 
          end
        rescue StandardError => err
          #need to do something to retry this - use new a13g func for this.
          logger.error "transcribe_data retrycount(#{retry_count}): error: #{err.message}"
          sleep(1)
        end

      end

      result || []
    end

    def logger
      GoogleSpeech.logger
    end

  end
end
