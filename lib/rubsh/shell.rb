module Rubsh
  class Shell
    class Env
      attr_reader :path

      def initialize
        @path = ::ENV["PATH"].split(::File::PATH_SEPARATOR)
      end

      def path=(path)
        @path = [*path]
      end
    end

    attr_reader :env
    attr_writer :logger

    def initialize
      @env = Env.new
      @logger = nil
    end

    def command(prog)
      Command.new(self, prog)
    end
    alias_method :cmd, :command

    def pipeline(**kwarg)
      r = RunningPipeline.new(self).tap { |x| yield x }
      r.__run(**kwarg)
      r
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
