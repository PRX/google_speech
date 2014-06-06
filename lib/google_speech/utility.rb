# -*- encoding: utf-8 -*-

require 'tempfile'
require 'open3'

module GoogleSpeech

  class Utility

    SOX_ERROR_RE = /error:/

    class <<self

      def audio_file_duration(path)
        check_local_file(path)

        soxi_duration, err = run_command("soxi -V0 -D '#{path}'", :nice=>false, :echo_return=>false)
        duration = soxi_duration.chomp.to_f
        duration
      end

      def trim_and_encode(wav_path, flac_path, start, length, rate)
        check_local_file(wav_path)

        command = "sox -t wav '#{wav_path}' -r 8000 -c 1 -t flac '#{flac_path}' trim #{start} #{length} compand .5,2 -80,-80,-75,-50,-30,-15,0,0 norm -0.1"
        # command = "sox -t wav '#{wav_path}' -t wav '#{flac_path}' norm channels 1 rate #{rate} trim #{start} #{length} compand .5,2 -80,-80,-75,-50,-30,-15,0,0"
        out, err = run_command(command)
        response = out + err
        response.split("\n").each{ |l| raise("trim_and_encode: error cmd: '#{command}'\nout: '#{response}'") if l =~ SOX_ERROR_RE }
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
        
        # logger.info "google_speech - run_command: #{cmd}"
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
        GoogleSpeech.logger        
      end

    end    
  end

end
