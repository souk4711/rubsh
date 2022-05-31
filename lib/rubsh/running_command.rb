module Rubsh
  class RunningCommand
    USED_RESERVED_WORDS = %i[
      _out
      _err
      _err_to_out
      _bg
      _env
      _cwd
      _ok_code
      _in
      _no_out
      _no_err
      _long_sep
      _long_prefix
    ]

    def initialize(prog, progpath, *args, **kwargs)
      @prog = prog
      @progpath = progpath
      @args = []

      # Special Kwargs - Controlling Output
      @_out = nil
      @_err = nil
      @_err_to_out = false

      # Special Kwargs - Execution
      @_bg = false
      @_env = nil
      @_cwd = nil
      @_ok_code = 0

      # Special Kwargs - Communication
      @_in = nil

      # Special Kwargs - Performance & Optimization
      @_no_out = false
      @_no_err = false

      # Special Kwargs - Program Arguments
      @_long_sep = "="
      @_long_prefix = "--"

      opts = []
      args.each { |arg| opts << Option.build(arg) }
      kwargs.each { |k, v| opts << Option.build(k, v) }
      extract_opts(opts)
    end

    def run!
      args = @args.map { |arg| arg.compile(long_sep: @_long_sep, long_prefix: @_long_prefix) }.compact.flatten
      Rubsh.logger.debug([@progpath].concat(args).join(" "))

      pid = Process.spawn([@progpath, @prog], *args)
      Process.wait(pid)
    end

    private

    def extract_opts(opts)
      opts.each do |opt|
        if opt.v.nil? # positional argument
          @args << Argument.new(opt.k, nil)
        elsif opt.k.start_with?("_") # keyword argument - Special Kwargs
          raise ::ArgumentError, format("Future reserved word: %s", opt.k) unless USED_RESERVED_WORDS.include?(opt.k.to_sym)
          extract_running_command_opt(opt)
        else # keyword argument
          @args << Argument.new(opt.k, opt.v)
        end
      end
    end

    def extract_running_command_opt(opt)
    end
  end
end
