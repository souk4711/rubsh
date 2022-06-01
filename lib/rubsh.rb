# frozen_string_literal: true

require_relative "rubsh/argument"
require_relative "rubsh/command"
require_relative "rubsh/exceptions"
require_relative "rubsh/option"
require_relative "rubsh/running_command"
require_relative "rubsh/running_pipeline"
require_relative "rubsh/shell"
require_relative "rubsh/version"

module Rubsh
  def self.cmd(prog)
    default_sh.cmd(prog)
  end

  def self.pipeline
    default_sh.pipeline.tap { |x| yield x }
  end

  def self.default_sh
    @default_sh ||= Shell.new
  end
end
