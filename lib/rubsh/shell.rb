module Rubsh
  class Shell
    attr_writer :logger

    def cmd(prog)
      Command.new(self, prog)
    end

    def pipeline
      Pipeline.new(self)
    end

    def logger
      return @logger if @logger

      require "logger"
      @logger = ::Logger.new($stdout, formatter: proc { |severity, datetime, progname, msg|
        msg =
          case msg
          when ::String then msg
          when ::Exception then "#{msg.message} (#{msg.class})\n#{msg.backtrace&.join("\n")}"
          else msg.inspect
          end
        format("%s, [%s #%d] %5s -- %s: %s\n", severity[0..0], datetime, ::Process.pid, severity, "rubsh", msg)
      })
    end
  end
end
