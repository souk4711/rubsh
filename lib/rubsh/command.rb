module Rubsh
  class Command < BasicObject
    def initialize(prog)
      @prog = prog
      @progpath = _resolve_progpath(@prog)
      @baked_opts = []
    end

    def method_missing(name, *args, **kwargs)
      ::Kernel.raise ::ArgumentError, ::Kernel.format("Reserved word: %s", name) if %i[is_a? inspect methods].include?(name) # Suppress IRB/Pry warning
      ::Kernel.raise ::ArgumentError, ::Kernel.format("Future reserved word: %s", name) if name.start_with?("_")
      call(name, *args, **kwargs)
    end

    def respond_to_missing?(name, include_private = false)
      true
    end

    def call(*args, **kwargs)
      rcmd = RunningCommand.new(@prog, @progpath, *@baked_opts, *args, **kwargs)
      rcmd.run!
      rcmd
    end

    def _bake(*args, **kwargs)
      cmd = Command.new(@prog)
      cmd.__send__(:_bake!, *@baked_opts, *args, **kwargs)
      cmd
    end

    private

    def _resolve_progpath(prog)
      if ::File.absolute_path?(prog)
        if ::File.executable?(prog) && ::File.file?(prog)
          progpath = prog
        end
      else
        ::ENV["PATH"].split(::File::PATH_SEPARATOR).each do |path|
          filepath = ::File.join(path, prog)
          if ::File.executable?(filepath) && ::File.file?(filepath)
            progpath = filepath
            break
          end
        end
      end

      ::Kernel.raise Exceptions::CommandNotFoundError if progpath.nil?
      progpath
    end

    def _bake!(*args, **kwargs)
      args.each { |arg| @baked_opts << Option.build(arg) }
      kwargs.each { |k, v| @baked_opts << Option.build(k, v) }
    end
  end
end
