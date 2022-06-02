require "timeout"

module Rubsh
  class RunningCommand
    SPECIAL_KWARGS = %i[
      _out
      _err
      _err_to_out
      _bg
      _env
      _timeout
      _cwd
      _ok_code
      _in
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
      @_timeout = nil
      @_cwd = nil
      @_ok_code = [0]

      # Special Kwargs - Communication
      @_in = nil

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

    def wait(timeout: nil)
      _, status = nil, nil
      if timeout
        begin
          ::Timeout.timeout(timeout) { _, status = ::Process.wait2(@pid) }
        rescue ::Timeout::Error
          timeout_occurred = true
          ::Process.kill("TERM", @pid) # graceful stop
          30.times do
            _, status = ::Process.wait2(@pid, ::Process::WNOHANG | ::Process::WUNTRACED)
            sleep 0.1 if status.nil?
          end
          ::Process.kill("KILL", @pid) # forceful stop
        end
      else
        _, status = ::Process.wait2(@pid)
      end

      @exit_code = status&.exitstatus
      @stdout_data = @out_rd&.read || ""
      @stderr_data = @err_rd&.read || ""
      raise Exceptions::CommandTimeoutError if timeout_occurred
    rescue Errno::ECHILD, Errno::ESRCH
      raise Exceptions::CommandTimeoutError if timeout_occurred
    ensure
      @in_wr&.close
      @out_rd&.close
      @err_rd&.close
    end

    # @!visibility private
    def __run
      if @_pipeline
        @_pipeline.__add_running_command(self)
      else
        @_bg ? run_in_background : run_in_foreground
      end
    end

    # @!visibility private
    def __run_in_pipeline(redirection_args)
      spawn(redirection_args: redirection_args)
    end

    private

    def extract_opts(opts)
      opts.each do |opt|
        if opt.positional? # positional argument
          @args << Argument.new(opt.k)
        elsif opt.k.to_s[0] == "_" # keyword argument - Special Kwargs
          raise ::ArgumentError, format("Unsupported Kwargs: %s", opt.k) unless SPECIAL_KWARGS.include?(opt.k.to_sym)
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
        @_env = opt.v.transform_keys(&:to_s).transform_values(&:to_s)
      when :_timeout
        @_timeout = opt.v
      when :_cwd
        @_cwd = opt.v
      when :_ok_code
        @_ok_code = [*opt.v]
      when :_in
        @_in = opt.v
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
        args[@_err_to_out ? [:out, :err] : :out] = @_out
      else
        @out_rd, @out_wr = ::IO.pipe
        args[@_err_to_out ? [:out, :err] : :out] = @out_wr.fileno
      end

      unless @_err_to_out
        if @_err
          args[:err] = @_err
        else
          @err_rd, @err_wr = ::IO.pipe
          args[:err] = @err_wr.fileno
        end
      end

      args
    end

    def compile_extra_args
      args = {}
      args[:chdir] = @_cwd if @_cwd
      args
    end

    def spawn(redirection_args: nil)
      cmd_args = compile_cmd_args
      redirection_args ||= compile_redirection_args
      extra_args = compile_extra_args
      @sh.logger.debug([@progpath].concat(cmd_args).join(" "))

      @pid =
        if @_env
          ::Process.spawn(@_env, [@progpath, @prog], *cmd_args, **redirection_args, **extra_args, unsetenv_others: true)
        else
          ::Process.spawn([@progpath, @prog], *cmd_args, **redirection_args, **extra_args)
        end
    ensure
      @in_rd&.close
      @out_wr&.close
      @err_wr&.close
    end

    def handle_return_code
      return if @_ok_code.include?(@exit_code)
      raise Exceptions::CommandReturnFailureError, @exit_code
    end

    def run_in_background
      spawn
      Process.detach(@pid)
    end

    def run_in_foreground
      spawn
      wait(timeout: @_timeout)
      handle_return_code
    end
  end
end
