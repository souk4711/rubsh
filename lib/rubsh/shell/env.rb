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
  end
end
