require 'rubygems'
require 'google_speech/version'

require 'excon'

require 'tempfile'
require 'open3'
require 'logger'
require 'cgi'
require 'json'

module GoogleSpeech

  SOX_ERROR_RE       = /error:/

  class Transcriber
    attr_accessor :original_file, :options, :results

    def initialize(original_file, options=nil)
      @original_file = original_file
      @options = {:language=>'en-US', :chunk_duration=>8, :overlap=>1, :max_results=>2}.merge(options || {})
      @results = []
    end

    def transcribe
      ChunkFactory.new(@original_file, options[:chunk_duration], options[:overlap]).each{|chunk|
        result = chunk.to_hash
        transcript = transcribe_data(chunk.data)
        result[:text] = transcript['hypotheses'].first['utterance']
        result[:confidence] = transcript['hypotheses'].first['confidence']
        @results << result
        puts "\n#{result[:start_time]} - #{result[:start_time].to_i + result[:duration].to_i}: #{(result[:confidence].to_f * 100).to_i}%: #{result[:text]}"
        sleep(1)
      }
      @results
    end

    def transcribe_data(data)
      params = {
        :scheme   => 'https',
        :host     => 'www.google.com',
        :port     => 443,
        :path     => "/speech-api/v1/recognize",
        :query    => "xjerr=1&client=google_speech&lang=#{options[:language]}&maxresults=#{options[:max_results].to_i}",
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

  # break wav audio into short files
  class ChunkFactory
    attr_accessor :original_file, :chunk_duration, :overlap

    def initialize(original_file, chunk_duration=8, overlap=1)
      @chunk_duration    = chunk_duration.to_i
      @original_file     = original_file
      @overlap           = overlap
      @original_duration = GoogleSpeech::Utility.audio_file_duration(@original_file.path).to_i
    end

    # return temp file for each chunk
    def each
      pos = 0
      while(pos < @original_duration) do
        chunk = Chunk.new(@original_file, @original_duration, pos, (@chunk_duration + @overlap))
        yield chunk
        pos = pos + [chunk.duration, @chunk_duration].min
      end
    end
  end

  class Chunk
    attr_accessor :original_file, :original_duration, :start_time, :duration, :chunk_file

    def initialize(original_file, original_duration, start_time, duration)
      @original_file = original_file
      @original_duration = original_duration.to_i
      @start_time = start_time.to_i
      @duration = [duration.to_i, (@original_duration - @start_time)].min
      @chunk_file = Tempfile.new([File.basename(@original_file), '.flac'])
      # puts "@chunk_file: #{@chunk_file.path}"
      Utility.trim_to_flac(@original_file.path, @duration, @chunk_file.path, @start_time, @duration)
    end

    def to_hash
      {
        :start_time => @start_time,
        :duration => @duration
      }
    end

    def data
      @data ||= @chunk_file.read
    end
  end

  # send each to google api

  class Utility
    class <<self

      def audio_file_duration(path)
        check_local_file(path)

        soxi_duration, err = run_command("soxi -V0 -D #{path}", :nice=>false, :echo_return=>false)
        duration = soxi_duration.chomp.to_f
        duration
      end

      def trim_to_flac(wav_path, duration, flac_path, start, length)
        check_local_file(wav_path)

        command = "sox -t wav '#{wav_path}' -t flac '#{flac_path}' trim #{start.to_i} #{length.to_i} rate 16k"
        out, err = run_command(command)
        response = out + err
        response.split("\n").each{ |l| raise("trim_to_flac: error cmd: '#{command}'\nout: '#{response}'") if l =~ SOX_ERROR_RE }
      end

      # Pass the command to run, and various options
      # :timeout - seconds to wait for command to complete, defaults to 2 hours
      # :echo_return - gets the return value via appended '; echo $?', true by default
      # :nice - call with nice -19 by default, set to false to stop, or integer to set different level
      def run_command(command, options={})
        timeout = options[:timeout] || 7200
        
        # default to adding a nice 19 if nothing specified
        nice = if options.key?(:nice)
          !options[:nice] ? '' : "nice -n #{options[:nice].to_i} "
        else
          'nice -n 19 '
        end
        
        echo_return = (options.key?(:echo_return) && !options[:echo_return]) ? '' : '; echo $?'
        
        cmd = "#{nice}#{command}#{echo_return}"
        
        # logger.debug "run_command:  #{cmd}"
        begin
          result = Timeout::timeout(timeout) {
            Open3::popen3(cmd) do |i,o,e|
              out_str = ""
              err_str = ""
              i.close # important!
              o.sync = true
              e.sync = true
              o.each{|line|
                out_str << line
                line.chomp!
                # logger.debug "stdout:    #{line}"
              }
              e.each { |line| 
                err_str << line
                line.chomp!
                # logger.debug "stderr:    #{line}"
              }
              return out_str, err_str
            end
          }
        rescue Timeout::Error => toe
          # logger.debug "run_command:Timeout Error - running command, took longer than #{timeout} seconds to execute: '#{cmd}'"
          raise toe
        end
      end

      def check_local_file(file_path)
        raise "File missing or 0 length: #{file_path}" unless (File.size?(file_path).to_i > 0)
      end

      def logger
        @logger ||= Logger.new(STDOUT)
      end

      def logger=(l)
        @logger = l
      end

    end    
  end

end
