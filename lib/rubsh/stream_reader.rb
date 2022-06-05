module Rubsh
  class StreamReader
    BUFSIZE = 16 * 1024

    def initialize(rd, bufsize: nil, &block)
      @thr = ::Thread.new do
        if ::Thread.current.respond_to?(:report_on_exception)
          ::Thread.current.report_on_exception = false
        end

        readers = [rd]
        while readers.any?
          ready = ::IO.select(readers, nil, readers)
          ready[0].each do |reader|
            if bufsize.nil?
              chunk = reader.readpartial(BUFSIZE)
            elsif bufsize == 0
              chunk = reader.readline
            else
              chunk = reader.read(bufsize)
              raise ::EOFError if chunk.nil?
            end

            chunk.force_encoding(::Encoding.default_external)
            block.call(chunk)
          rescue ::EOFError, ::Errno::EPIPE, ::Errno::EIO
            readers.delete(reader)
            reader.close
          end
        end
      end
    end

    # @return [void]
    def wait
      @thr.join
    end
  end
end
