module Rubsh
  class Command
    def initialize(sh, prog)
      @sh = sh
      @prog = prog.to_s
      @progpath = resolve_progpath(@prog)
      @baked_opts = []
    end

    def call_with(*args, **kwargs, &block)
      rcmd = RunningCommand.new(@sh, @prog, @progpath, *@baked_opts, *args, **kwargs, &block)
      rcmd.__run
      rcmd
    end
    alias_method :call, :call_with

    def bake(*args, **kwargs)
      cmd = Command.new(@sh, @prog)
      cmd.__bake!(*@baked_opts, *args, **kwargs)
      cmd
    end

    # @!visibility private
    def __bake!(*args, **kwargs)
      args.each { |arg| @baked_opts << Option.build(arg) }
      kwargs.each { |k, v| @baked_opts << Option.build(k, v) }
    end

    private

    def resolve_progpath(prog)
      if ::File.expand_path(prog) == prog
        if ::File.executable?(prog) && ::File.file?(prog)
          progpath = prog
        end
      else
        @sh.path.each do |path|
          filepath = ::File.join(path, prog)
          if ::File.executable?(filepath) && ::File.file?(filepath)
            progpath = filepath
            break
          end
        end
      end

      raise Exceptions::CommandNotFoundError if progpath.nil?
      progpath
    end
  end
end
