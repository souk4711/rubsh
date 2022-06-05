module Rubsh
  # Represents an un-run system program, like "ls" or "cd". Because it represents
  # the program itself (and not a running instance of it), it should hold very
  # little state. In fact, the only state it does hold is baked options.
  #
  # When a Command object is called, the result that is returned is a RunningCommand
  # object, which represents the Command put into an execution state.
  class Command
    def initialize(sh, prog)
      @sh = sh
      @prog = prog.to_s
      @progpath = resolve_progpath(@prog)
      @baked_opts = []
    end

    # @param args[String, Symbol, #to_s, Hash]
    # @param kwargs[Hash]
    # @return [RunningCommand] An new instance of RunningCommand with execution state.
    # @example
    #
    #   sh = Rubsh::Shell.new
    #   git = Rubsh::Command.new(sh, "git")
    #   git.call()                                  # => ["git"]
    #   git.call("")                                # => ["git", ""]
    #   git.call("status")                          # => ["git", "status"]
    #   git.call(:status)                           # => ["git", "status"]
    #   git.call(:status, "-v")                     # => ["git", "status", "-v"]
    #   git.call(:status, v: true)                  # => ["git", "status", "-v"]
    #   git.call(:status, { v: true }, "--", ".")   # => ["git", "status", "-v", "--", "."]
    #   git.call(:status, { v: proc{ true }, short: true }, "--", ".")  # => ["git", "status", "-v", "--short=true", "--", "."]
    #   git.call(:status, { untracked_files: "normal" }, "--", ".")     # =>["status", "--untracked-files=normal", "--", "."])
    def call(*args, **kwargs)
      rcmd = RunningCommand.new(@sh, @prog, @progpath, *@baked_opts, *args, **kwargs)
      rcmd.__run
      rcmd
    end
    alias_method :call_with, :call

    # @param args[String, Symbol, #to_s, Hash]
    # @param kwargs[Hash]
    # @return [Command] a new instance of Command with baked options.
    def bake(*args, **kwargs)
      cmd = Command.new(@sh, @prog)
      cmd.__bake!(*@baked_opts, *args, **kwargs)
      cmd
    end

    # @return [String]
    def inspect
      format("#<Rubsh::Command '%s'>", @progpath)
    end

    # @!visibility private
    def __bake!(*args, **kwargs)
      args.each do |arg|
        if arg.is_a?(::Hash)
          arg.each { |k, v| @baked_opts << Option.build(k, v) }
        else
          @baked_opts << Option.build(arg)
        end
      end
      kwargs.each { |k, v| @baked_opts << Option.build(k, v) }
    end

    private

    def resolve_progpath(prog)
      if ::File.expand_path(prog) == prog
        if ::File.executable?(prog) && ::File.file?(prog)
          progpath = prog
        end
      else
        @sh.env.path.each do |path|
          filepath = ::File.join(path, prog)
          if ::File.executable?(filepath) && ::File.file?(filepath)
            progpath = filepath
            break
          end
        end
      end

      raise Exceptions::CommandNotFoundError, format("no command `%s'", prog) if progpath.nil?
      progpath
    end
  end
end
