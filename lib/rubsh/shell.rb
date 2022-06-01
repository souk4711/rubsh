module Rubsh
  class Shell
    attr_writer :logger

    def cmd(prog)
      Command.new(self, prog)
    end

    def pipeline
      RunningPipeline.new(self).tap { |x| yield x }
    end

    def logger
      return @logger if @logger

      require "logger"
      @logger = begin
        logger = ::Logger.new($stdout)
        logger.level = ::Logger::WARN

        formatter = ::Logger::Formatter.new
        logger.formatter = proc do |severity, datetime, progname, msg|
          formatter.call(severity, datetime, "rubsh", msg.dump)
        end

        logger
      end
    end
  end
end
