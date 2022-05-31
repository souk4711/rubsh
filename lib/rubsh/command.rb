module Rubsh
  class Command < BasicObject
    def initialize(prog)
      @prog = prog
      @baked_opts = []
    end

    def method_missing(name, *args, **kwargs)
      ::Kernel.raise ::ArgumentError, format("Reserved word: %s", name) if %i[is_a? inspect methods].include?(name) # Suppress IRB/Pry warning
      ::Kernel.raise ::ArgumentError, format("Future reserved word: %s", name) if name.start_with?("_")
      call(name, *args, **kwargs)
    end

    def respond_to_missing?(name, include_private = false)
      true
    end

    def call(*args, **kwargs)
      rcmd = RunningCommand.new(@prog, *@baked_opts, *args, **kwargs)
      rcmd.run!
      rcmd
    end

    def _bake(*args, **kwargs)
      cmd = Command.new(@prog)
      cmd.__send__(:_bake!, *@baked_opts, *args, **kwargs)
      cmd
    end

    private

    def _bake!(*args, **kwargs)
      args.each { |arg| @baked_opts << Option.build(arg) }
      kwargs.each { |k, v| @baked_opts << Option.build(k, v) }
    end
  end
end
