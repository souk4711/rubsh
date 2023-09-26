module Rubsh
  class RunningCommand
    SPECIAL_KWARGS = %i[
      _in_data
      _in
      _out
      _err
      _err_to_out
      _capture
      _bg
      _env
      _timeout
      _cwd
      _ok_code
      _out_bufsize
      _err_bufsize
      _no_out
      _no_err
      _long_sep
      _long_prefix
      _pipeline
    ]

    SPECIAL_KWARGS_WITHIN_PIPELINE = %i[
      _env
      _cwd
      _long_sep
      _long_prefix
      _pipeline
    ]

    # @!attribute [r] pid
    # @return [Number]
    attr_reader :pid

    # @!attribute [r] exit_code
    # @return [Number]
    attr_reader :exit_code

    # @!attribute [r] started_at
    # @return [Time]
    attr_reader :started_at

    # @!attribute [r] finished_at
    # @return [Time]
    attr_reader :finished_at

    # @!attribute [r] stdout_data
    # @return [String]
    attr_reader :stdout_data

    # @!attribute [r] stderr_data
    # @return [String]
    attr_reader :stderr_data

    def initialize(sh, prog, progpath, *args, **kwargs)
      @sh = sh
      @prog = prog
      @progpath = progpath
      @args = []

      # Runtime
      @prog_with_args = nil
      @pid = nil
      @exit_code = nil
      @started_at = nil
      @finished_at = nil
      @stdout_data = "".force_encoding(::Encoding.default_external)
      @stderr_data = "".force_encoding(::Encoding.default_external)
      @in_rd = nil
      @in_wr = nil
      @out_rd = nil
      @out_wr = nil
      @err_rd = nil
      @err_wr = nil
      @out_rd_reader = nil
      @err_rd_reader = nil

      # Special Kwargs - Controlling Input/Output
      @_in_data = nil
      @_in = nil
      @_out = nil
      @_err = nil
      @_err_to_out = false
      @_capture = nil

      # Special Kwargs - Execution
      @_bg = false
      @_env = nil
      @_timeout = nil
      @_cwd = nil
      @_ok_code = [0]

      # Special Kwargs - Performance & Optimization
      @_out_bufsize = 0
      @_err_bufsize = 0
      @_no_out = false
      @_no_err = false

      # Special Kwargs - Program Arguments
      @_long_sep = "="
      @_long_prefix = "--"

      # Special Kwargs - Misc
      @_pipeline = nil

      opts = []
      args.each do |arg|
        if arg.is_a?(::Hash)
          arg.each { |k, v| opts << Option.build(k, v) }
        else
          opts << Option.build(arg)
        end
      end
      kwargs.each { |k, v| opts << Option.build(k, v) }
      validate_opts(opts)
      extract_opts(opts)
    end

    # @return [Numeric, nil]
    def wall_time
      @finished_at.nil? ? nil : @finished_at - @started_at
    end
    alias_method :execution_time, :wall_time

    # @return [Boolean]
    def ok?
      @_ok_code.include?(@exit_code)
    end

    # @return [void]
    def wait(timeout: nil)
      wait2(timeout: timeout)
      handle_return_code
    end

    # @return [String]
    def to_s
      @prog_with_args
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
    def __spawn_arguments(env: nil, cwd: nil, redirection_args: nil)
      env ||= @_env
      cmd_args = compile_cmd_args
      redirection_args ||= compile_redirection_args
      extra_args = compile_extra_args(cwd: cwd)

      # For logging
      @prog_with_args = [@progpath].concat(cmd_args).join(" ")

      # .
      _args =
        if env
          [env, [@progpath, @prog], *cmd_args, **redirection_args, **extra_args, unsetenv_others: true]
        else
          [[@progpath, @prog], *cmd_args, **redirection_args, **extra_args]
        end
    end

    # @!visibility private
    def __prog_with_args
      @prog_with_args
    end

    private

    def validate_opts(opts)
      within_pipeline = opts.any? { |opt| opt.special_kwarg?(:_pipeline) }
      within_pipeline && opts.each do |opt|
        if opt.special_kwarg? && !SPECIAL_KWARGS_WITHIN_PIPELINE.include?(opt.k.to_sym)
          raise ::ArgumentError, format("unsupported special kwargs within _pipeline `%s'", opt.k)
        end
      end
    end

    def extract_opts(opts)
      args_hash = {}
      opts.each do |opt|
        if opt.positional? # positional argument
          @args << Argument.new(opt.k)
        elsif opt.special_kwarg? # keyword argument - Special Kwargs
          raise ::ArgumentError, format("unsupported special kwargs `%s'", opt.k) unless SPECIAL_KWARGS.include?(opt.k.to_sym)
          extract_special_kwargs_opts(opt)
        elsif args_hash.key?(opt.k) # keyword argument
          arg = args_hash[opt.k]
          arg.value = opt.v
        else
          arg = Argument.new(opt.k, opt.v)
          args_hash[opt.k] = arg
          @args << arg
        end
      end
    end

    def extract_special_kwargs_opts(opt)
      case opt.k.to_sym
      when :_in_data
        @_in_data = opt.v
      when :_in
        @_in = opt.v
      when :_out
        @_out = opt.v
      when :_err
        @_err = opt.v
      when :_err_to_out
        @_err_to_out = opt.v
      when :_capture
        @_capture = opt.v
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
      when :_out_bufsize
        @_out_bufsize = opt.v
      when :_err_bufsize
        @_err_bufsize = opt.v
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
        @in_wr.sync = true
        args[:in] = @in_rd.fileno
      end

      if @_out
        args[:out] = @_out
      else
        @out_rd, @out_wr = ::IO.pipe
        args[:out] = @out_wr.fileno
      end

      if @_err_to_out
        args[:err] = [:child, :out]
      elsif @_err
        args[:err] = @_err
      else
        @err_rd, @err_wr = ::IO.pipe
        args[:err] = @err_wr.fileno
      end

      args
    end

    def compile_extra_args(cwd: nil)
      chdir = cwd || @_cwd

      args = {}
      args[:chdir] = chdir if chdir
      args
    end

    def spawn
      args = __spawn_arguments
      @pid = ::Process.spawn(*args)
      @started_at = Time.now
      @in_wr&.write(@_in_data) if @_in_data
      @in_wr&.close

      if @out_rd
        @out_rd_reader = StreamReader.new(@out_rd, bufsize: @_capture ? @_out_bufsize : nil, &proc { |chunk|
          @stdout_data << chunk unless @_no_out
          @_capture&.call(chunk, nil)
        })
      end
      if @err_rd
        @err_rd_reader = StreamReader.new(@err_rd, bufsize: @_capture ? @_err_bufsize : nil, &proc { |chunk|
          @stderr_data << chunk unless @_no_err
          @_capture&.call(nil, chunk)
        })
      end
    ensure
      @in_rd&.close
      @out_wr&.close
      @err_wr&.close
    end

    def wait2(timeout: nil)
      timeout_occurred = false
      _, status = nil, nil

      if timeout
        begin
          ::Timeout.timeout(timeout) { _, status = ::Process.wait2(@pid) }
        rescue ::Timeout::Error
          timeout_occurred = true

          ::Process.kill("TERM", @pid) # graceful stop
          30.times do
            _, status = ::Process.wait2(@pid, ::Process::WNOHANG | ::Process::WUNTRACED)
            break if status
            sleep 0.1
          end
          failure = @pid if status.nil?
          failure && ::Process.kill("KILL", failure) # forceful stop
        end
      else
        _, status = ::Process.wait2(@pid)
      end

      @exit_code = status&.exitstatus
      @finished_at = Time.now
      raise Exceptions::CommandTimeoutError, "execution expired" if timeout_occurred
    rescue Errno::ECHILD, Errno::ESRCH
      raise Exceptions::CommandTimeoutError, "execution expired" if timeout_occurred
    ensure
      @out_rd_reader&.wait
      @err_rd_reader&.wait
    end

    def handle_return_code
      return if ok?
      message = format("\n\n  RAN: %s\n\n  STDOUT:\n%s\n  STDERR:\n%s\n", @prog_with_args, @stdout_data, @stderr_data)
      raise Exceptions::CommandReturnFailureError.new(@exit_code, message)
    end

    def run_in_background
      spawn
      Process.detach(@pid)
    end

    def run_in_foreground
      spawn
      wait(timeout: @_timeout)
    end
  end
end
