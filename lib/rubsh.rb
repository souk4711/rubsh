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
end
