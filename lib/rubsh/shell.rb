module Rubsh
  class Shell
    attr_reader :env

    def initialize
      @env = Env.new
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
  end
end
