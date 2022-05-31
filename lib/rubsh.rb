# frozen_string_literal: true

require_relative "rubsh/argument"
require_relative "rubsh/command"
require_relative "rubsh/exceptions"
require_relative "rubsh/option"
require_relative "rubsh/running_command"
require_relative "rubsh/version"

module Rubsh
  def self.cmd(prog)
    Command.new(prog)
  end

  def self.logger
    return @logger if @logger

    require "logger"
    @logger = begin
      formatter = ::Logger::Formatter.new
      ::Logger.new($stdout, formatter: proc { |severity, datetime, progname, msg|
        formatter.call(severity, datetime, "rubsh", msg.dump)
      })
    end
  end

  def self.logger=(logger)
    @logger = logger
  end
end
