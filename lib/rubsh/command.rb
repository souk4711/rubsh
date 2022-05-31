module Rubsh
  class Command
    def initialize(prog)
      @prog = prog
      @progpath = resolve_progpath(@prog)
      @baked_opts = []
    end

    def call(*args, **kwargs)
      rcmd = RunningCommand.new(@prog, @progpath, *@baked_opts, *args, **kwargs)
      rcmd.run!
      rcmd
    end

    def bake(*args, **kwargs)
      cmd = Command.new(@prog)
      cmd.__send__(:bake!, *@baked_opts, *args, **kwargs)
      cmd
    end
    alias_method :subcommand, :bake

    private

    def resolve_progpath(prog)
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

      raise Exceptions::CommandNotFoundError if progpath.nil?
      progpath
    end

    def bake!(*args, **kwargs)
      args.each { |arg| @baked_opts << Option.build(arg) }
      kwargs.each { |k, v| @baked_opts << Option.build(k, v) }
    end
  end
end
