module Rubsh
  module Exceptions
    # Base error class.
    class Error < StandardError; end

    # Raised when a command not found.
    class CommandNotFoundError < Error; end

    # Raised when a command is killed because a specified timeout was hit.
    class CommandTimeoutError < Error; end
  end
end
