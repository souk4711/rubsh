require "open3"

module Rubsh
  class RunningPipeline
    SPECIAL_KWARGS = %i[
      _in_data
      _in
      _out
      _err
      _err_to_out
      _capture
      _bg
      _timeout
      _ok_code
      _out_bufsize
      _err_bufsize
      _no_out
      _no_err
    ]

    attr_reader :exit_code, :stdout_data, :stderr_data

    def initialize(sh)
      @sh = sh
      @rcmds = []

      # Runtime
      @prog_with_args = nil
      @exit_code = nil
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
      @waiters = []

      # Special Kwargs - Controlling Input/Output
      @_in_data = nil
      @_in = nil
      @_out = nil
      @_err = nil
      @_err_to_out = false
      @_capture = nil

      # Special Kwargs - Execution
      @_bg = false
      @_timeout = nil
      @_ok_code = [0]

      # Special Kwargs - Performance & Optimization
      @_out_bufsize = 0
      @_err_bufsize = 0
      @_no_out = false
      @_no_err = false
    end

    def wait(timeout: nil)
      timeout_occurred = false
      last_status = nil

      if timeout
        begin
          ::Timeout.timeout(timeout) { last_status = @waiters.map(&:value)[-1] }
        rescue ::Timeout::Error
          timeout_occurred = true

          failures = []
          @waiters.each { |w| ::Process.kill("TERM", w.pid) } # graceful stop
          @waiters.each { |w|
            _, status = nil, nil
            30.times do
              _, status = ::Process.wait2(w.pid, ::Process::WNOHANG | ::Process::WUNTRACED)
              break if status
              sleep 0.1
            rescue ::Errno::ECHILD, ::Errno::ESRCH
              status = true
            end
            failures << w.pid if status.nil?
          }
          failures.each { |pid| ::Process.kill("KILL", pid) } # forceful stop
        end
      else
        last_status = @waiters.map(&:value)[-1]
      end

      @exit_code = last_status&.exitstatus
      raise Exceptions::CommandTimeoutError if timeout_occurred
    rescue ::Errno::ECHILD, ::Errno::ESRCH
      raise Exceptions::CommandTimeoutError if timeout_occurred
    ensure
      @out_rd_reader&.wait
      @err_rd_reader&.wait
    end

    # @!visibility private
    def __add_running_command(cmd)
      @rcmds << cmd
    end

    # @!visibility private
    def __run(**kwargs)
      extract_opts(**kwargs)
      @_bg ? run_in_background : run_in_foreground
    end

    private

    def extract_opts(**kwargs)
      kwargs.each do |k, v|
        raise ::ArgumentError, format("Unsupported kwarg: %s", k) unless SPECIAL_KWARGS.include?(k.to_sym)
        case k.to_sym
        when :_in_data
          @_in_data = v
        when :_in
          @_in = v
        when :_out
          @_out = v
        when :_err
          @_err = v
        when :_err_to_out
          @_err_to_out = v
        when :_capture
          @_capture = v
        when :_bg
          @_bg = v
        when :_timeout
          @_timeout = v
        when :_ok_code
          @_ok_code = [*v]
        when :_out_bufsize
          @_out_bufsize = v
        when :_err_bufsize
          @_err_bufsize = v
        when :_no_out
          @_no_out = v
        when :_no_err
          @_no_err = v
        end
      end
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

    def spawn
      cmds = @rcmds.map { |r| r.__spawn_arguments(redirection_args: {}) }
      @prog_with_args = @rcmds.map(&:__prog_with_args).join(" | ")
      @sh.logger.info(@prog_with_args)

      @waiters = ::Open3.pipeline_start(*cmds, compile_redirection_args)
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

    def handle_return_code
      return if @_ok_code.include?(@exit_code)
      message = format("\n\n  RAN: %s\n\n  STDOUT:\n%s\n  STDERR:\n%s\n", @prog_with_args, @stdout_data, @stderr_data)
      raise Exceptions::CommandReturnFailureError.new(@exit_code, message)
    end

    def run_in_background
      spawn
    end

    def run_in_foreground
      spawn
      wait(timeout: @_timeout)
      handle_return_code
    end
  end
end
