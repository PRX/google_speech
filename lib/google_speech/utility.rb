# -*- encoding: utf-8 -*-

require 'tempfile'
require 'open3'
require 'logger'

module GoogleSpeech

  class Utility

    SOX_ERROR_RE       = /error:/

    class <<self

      def audio_file_duration(path)
        check_local_file(path)

        soxi_duration, err = run_command("soxi -V0 -D #{path}", :nice=>false, :echo_return=>false)
        duration = soxi_duration.chomp.to_f
        duration
      end

      def trim_to_flac(wav_path, duration, flac_path, start, length)
        check_local_file(wav_path)

        #command = "sox -t wav '#{wav_path}' -r 16000 -c 1 -t flac '#{flac_path}' trim #{start.to_i} #{length.to_i} compand .5,2 -80,-80,-75,-50,-30,-15,0,0 norm -0.1"

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
