# -*- encoding: utf-8 -*-

require 'tempfile'

module GoogleSpeech

  class Chunk
    attr_accessor :original_file, :original_duration, :start_time, :duration, :chunk_file, :rate

    def initialize(original_file, original_duration, start_time, duration, rate)
      @original_file     = original_file
      @original_duration = original_duration
      @start_time        = start_time
      @duration          = [duration, (@original_duration - @start_time)].min
      @rate              = rate
      @chunk_file        = Tempfile.new([File.basename(@original_file), '.wav'])
      # puts "@chunk_file: #{@chunk_file.path}"
      Utility.trim_and_encode(@original_file.path, @chunk_file.path, @start_time, @duration, @rate)
    end

    def to_hash
      {
        :start_time => @start_time,
        :end_time => @start_time + @duration
      }
    end

    def data
      @data ||= @chunk_file.read
    end

    def logger
      GoogleSpeech.logger        
    end

    def close_file
      return unless @chunk_file
      @chunk_file.close rescue nil
      @chunk_file.unlink rescue nil
    end

  end
end
