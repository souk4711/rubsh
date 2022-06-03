require "open3"

module Rubsh
  class RunningPipeline
    SPECIAL_KWARGS = %i[
      _in_data
      _in
      _out
      _err
      _ok_code
    ]

    attr_reader :stdout_data

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
      @pipes = []

      # Special Kwargs - Controlling Input/Output
      @_in_data = nil
      @_in = nil
      @_out = nil
      @_err = nil

      # Special Kwargs - Execution
      @_ok_code = [0]
    end

    # @!visibility private
    def __add_running_command(cmd)
      @rcmds << cmd
    end

    # @!visibility private
    def __run(**kwargs)
      extract_opts(**kwargs)

      cmds = @rcmds.map { |r| r.__spawn_arguments(redirection_args: {}) }
      @prog_with_args = @rcmds.map(&:__prog_with_args).join(" | ")
      @sh.logger.debug(@prog_with_args)

      Open3.pipeline_start(*cmds, compile_redirection_args) do |ts|
        # unused
        @in_rd&.close
        @out_wr&.close
        @err_wr&.close

        # input
        @in_wr&.write(@_in_data) if @_in_data
        @in_wr&.close

        begin
          # wait
          last_status = ts.map(&:value)[-1]
          @exit_code = last_status&.exitstatus

          # output & errput
          @stdout_data = @out_rd&.read || ""
          @stdout_data.force_encoding(::Encoding.default_external)
          @stderr_data = @err_rd&.read || ""
          @stderr_data.force_encoding(::Encoding.default_external)
        ensure
          @out_rd&.close
          @err_rd&.close
        end

        # .
        handle_return_code
      end

      self
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
        when :_ok_code
          @_ok_code = [*v]
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

      if @_err
        args[:err] = @_err
      else
        @err_rd, @err_wr = ::IO.pipe
        args[:err] = @err_wr.fileno
      end

      args
    end

    def handle_return_code
      return if @_ok_code.include?(@exit_code)

      message = format("\n\n  RAN: %s\n\n  STDOUT:\n%s\n  STDERR:\n%s\n", @prog_with_args, @stdout_data, @stderr_data)
      raise Exceptions::CommandReturnFailureError.new(@exit_code, message)
    end
  end
end
