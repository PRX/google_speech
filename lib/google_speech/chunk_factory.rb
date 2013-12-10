# -*- encoding: utf-8 -*-

module GoogleSpeech

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

    def logger
      GoogleSpeech.logger
    end

  end
end
