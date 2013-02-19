# -*- encoding: utf-8 -*-

require 'tempfile'

module GoogleSpeech

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
        :end_time => @start_time + @duration
      }
    end

    def data
      @data ||= @chunk_file.read
    end
  end

end
