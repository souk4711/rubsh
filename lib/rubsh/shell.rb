module Rubsh
  class Shell
    # @!attribute [r] env
    # @return [Env]
    attr_reader :env

    def initialize
      @env = Env.new
    end

    # @return [Command]
    def command(prog)
      Command.new(self, prog)
    end
    alias_method :cmd, :command

    # @return [RunningPipeline]
    def pipeline(**kwarg)
      r = RunningPipeline.new(self).tap { |x| yield x }
      r.__run(**kwarg)
      r
    end
  end
end
