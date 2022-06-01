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
      _pipeline
    ]

    attr_reader :pid, :exit_code, :stdout_data, :stderr_data

    def initialize(sh, prog, progpath, *args, **kwargs)
      @sh = sh
      @prog = prog
      @progpath = progpath
      @args = []
      @pid = nil
      @exit_code = nil
      @stdout_data = nil
      @stderr_data = nil
      @in_rd = nil
      @in_wr = nil
      @out_rd = nil
      @out_wr = nil
      @err_rd = nil
      @err_wr = nil

      # Special Kwargs - Controlling Output
      @_out = nil
      @_err = nil
      @_err_to_out = false

      # Special Kwargs - Execution
      @_bg = false
      @_env = nil
      @_cwd = nil
      @_ok_code = [0]

      # Special Kwargs - Communication
      @_in = nil

      # Special Kwargs - Performance & Optimization
      @_no_out = false
      @_no_err = false

      # Special Kwargs - Program Arguments
      @_long_sep = "="
      @_long_prefix = "--"

      # Special Kwargs - Misc
      @_pipeline = nil

      opts = []
      args.each { |arg| opts << Option.build(arg) }
      kwargs.each { |k, v| opts << Option.build(k, v) }
      extract_opts(opts)
    end

    def call
      if @_pipeline
        @_pipeline.add_running_command(self)
      else
        run
      end
    end

    def run
      cmd_args = @args.map { |arg| arg.compile(long_sep: @_long_sep, long_prefix: @_long_prefix) }.compact.flatten
      redirection_args = compile_redirection_args

      @sh.logger.debug([@progpath].concat(cmd_args).join(" "))
      @pid = ::Process.spawn([@progpath, @prog], *cmd_args, **redirection_args)

      @in_rd&.close
      @out_wr&.close
      @err_wr&.close

      wait

      @stdout_data = @out_rd&.read
      @stderr_data = @err_rd&.read
      @in_wr&.close
      @out_rd&.close
      @err_rd&.close

      handle_return_code
      self
    end

    def run_in_pipeline(redirection_args)
      cmd_args = @args.map { |arg| arg.compile(long_sep: @_long_sep, long_prefix: @_long_prefix) }.compact.flatten

      @sh.logger.debug([@progpath].concat(cmd_args).join(" "))
      @pid = ::Process.spawn([@progpath, @prog], *cmd_args, **redirection_args)

      self
    end

    def wait
      _, status = ::Process.wait2(@pid)
      @exit_code = status.exitstatus
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
      case opt.k.to_sym
      when :_out
        @_out = opt.v
      when :_err
        @_err = opt.v
      when :_err_to_out
        @_err_to_out = opt.v
      when :_bg
        @_bg = opt.v
      when :_env
        @_env = opt.v
      when :_cwd
        @_cmd = opt.v
      when :_ok_code
        @_ok_code = [*opt.v]
      when :_in
        @_in = opt.v
      when :_no_out
        @_no_out = opt.v
      when :_no_err
        @_no_err = opt.v
      when :_long_sep
        @_long_sep = opt.v
      when :_long_prefix
        @_long_prefix = opt.v
      when :_pipeline
        @_pipeline = opt.v
      end
    end

    def compile_cmd_args
      @args.map { |arg| arg.compile(long_sep: @_long_sep, long_prefix: @_long_prefix) }.compact.flatten
    end

    def compile_redirection_args
      args = {}

      if @_in
        args[:in] = @_in
      else
        @in_rd, @in_wr = ::IO.pipe
        args[:in] = @in_rd.fileno
      end

      if @_out
        args[@_err_to_out ? [:out, :err] : :out] = @_out if @_out
      elsif !@_no_out
        @out_rd, @out_wr = ::IO.pipe
        args[@_err_to_out ? [:out, :err] : :out] = @out_wr.fileno
      end

      unless @_err_to_out
        if @_err
          args[:err] = @_err if @_err
        elsif !@_no_err
          @err_rd, @err_wr = ::IO.pipe
          args[:err] = @err_wr.fileno
        end
      end

      args
    end

    def handle_return_code
      return if @_ok_code.include?(@exit_code)
      raise Exceptions::CommandReturnFailureError, @exit_code
    end
  end
end
