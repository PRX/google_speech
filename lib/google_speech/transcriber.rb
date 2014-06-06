# -*- encoding: utf-8 -*-

require 'excon'
require 'json'
require 'uuid'

module GoogleSpeech

  class Transcriber
    attr_accessor :original_file, :options, :results

    DEFAULT_OPTIONS =   {
      # :key              => 'AIzaSyCnl6MRydhw_5fLXIdASxkLJzcJh5iX0M4',
      # :client           => SecureRandom.hex,
      :key              => 'AIzaSyBOti4mM-6x9WDnZIjIeyEU21OpBXqWBgw',
      :client           => 'chrome',
      :audio_type       => 'audio/x-flac',
      :rate             => 8000,
      :language         => 'en-us',
      :chunk_duration   => 4.0,
      :overlap          => 0.25,
      :max_results      => 1,
      :request_pause    => 0.1,
      :profanity_filter => true,
      :retry_max        => 2
    }

    def initialize(original_file, options=nil)
      @original_file = original_file
      @options = DEFAULT_OPTIONS.merge(options || {})
      @results = []
      @last_ua = 0
    end

    def open_working_file
      Utility.check_local_file(@original_file.path)
      wf_path = random_file_name(@original_file.path)
      FileUtils.ln(@original_file.path, wf_path)
      File.open(wf_path, 'r') {|f|
        yield f
      }
      FileUtils.rm(wf_path, :force=>true)
    end

    def random_file_name(path)
      File.join(GoogleSpeech::TMP_FILE_DIR, File.basename(path) + '_' + UUID.generate + '.wav')
    end

    def transcribe
      open_working_file do |working_file|
        chunk_factory = ChunkFactory.new(working_file, options[:chunk_duration], options[:overlap], options[:rate])
        chunk_factory.each{ |chunk|
          result = chunk.to_hash
          transcript = transcribe_data(chunk.data)
          next unless transcript

          result = result.merge(extract_result(transcript))

          logger.debug "#{result[:start_time]}: #{(result[:confidence].to_f * 100).to_i}%: #{result[:text]}"

          @results << result

          sleep(options[:request_pause].to_i)
        }
      end

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

    def user_agent
      ua_strings = [ 
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1944.0 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.47 Safari/537.36',
        'Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36 Mozilla/5.0 (iPad; U; CPU OS 3_2 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Version/4.0.4 Mobile/7B334b Safari/531.21.10',
        'Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1664.3 Safari/537.36',
        'Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/31.0.1650.16 Safari/537.36',
        'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/31.0.1623.0 Safari/537.36',
        'Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.17 Safari/537.36',
        'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.62 Safari/537.36',
        'Mozilla/5.0 (X11; CrOS i686 4319.74.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.57 Safari/537.36',
        'Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.2 Safari/537.36',
        'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1468.0 Safari/537.36',
        'Mozilla/5.0 (Windows NT 6.2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1467.0 Safari/537.36',
        'Mozilla/5.0 (Windows NT 6.2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1464.0 Safari/537.36',
        'Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.93 Safari/537.36',
        'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.93 Safari/537.36',
        'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.93 Safari/537.36',
        'Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.93 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.93 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.93 Safari/537.36'
      ]
      ua = ua_strings[(@last_ua % ua_strings.length)]
      @last_ua += 1
      ua
    end

    def transcribe_data(data)
      params = {
        :path     => "/speech-api/v2/recognize",
        :query    => "output=json&key=#{options[:key]}&client=#{options[:client]}&lang=#{options[:language]}",
        :body     => data,
        :method   => 'POST',
        :headers  => {
          'Content-Type'   => "#{options[:audio_type]}; rate=#{options[:rate]}",
          'Content-Length' => data.bytesize,
          'User-Agent'     => user_agent
        }
      }
      # puts "data size: #{data.bytesize}"
      retry_max = options[:retry_max] ? [options[:retry_max].to_i, 1].max : 3
      retry_count = 0
      result = nil
      url = "https://www.google.com#{params[:path]}"
      while(!result && retry_count < retry_max)
        retry_count += 1
        begin
          connection = Excon.new(url)
          response = connection.request(params)
          # puts "response: #{response.inspect}\n\n"
          # puts "response.headers:\n#{response.headers}\n"
          # puts "response.body:'#{response.body}'\n"
          if response.status.to_s.start_with?('2') && response.body != "{\"result\":[]}\n"
            result = []
            if (response.body && response.body.size > 0)
              result = response.body.split("\n").collect{|b| JSON.parse(b)} rescue []
            end
          else
            logger.error "        transcribe_data retrycount(#{retry_count}): status: #{response.status}, response: #{response.body.chomp}"
            sleep(options[:request_pause].to_i)
          end
        rescue StandardError => err
          #need to do something to retry this - use new a13g func for this.
          logger.error "        transcribe_data retrycount(#{retry_count}): error: #{err.message}"
          sleep(options[:request_pause].to_i)
        end

      end

      result || []
    end

    def logger
      GoogleSpeech.logger
    end

  end
end
