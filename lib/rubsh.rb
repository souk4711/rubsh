# frozen_string_literal: true

require "open3"
require "timeout"

require_relative "rubsh/argument"
require_relative "rubsh/command"
require_relative "rubsh/exceptions"
require_relative "rubsh/option"
require_relative "rubsh/running_command"
require_relative "rubsh/running_pipeline"
require_relative "rubsh/shell/env"
require_relative "rubsh/shell"
require_relative "rubsh/stream_reader"
require_relative "rubsh/version"

module Rubsh
  def self.new
    Shell.new
  end
end
