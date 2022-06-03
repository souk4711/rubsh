require "open3"

module Rubsh
  class RunningPipeline
    SPECIAL_KWARGS = %i[
      _out
      _in
      _in_data
    ]

    attr_reader :stdout_data

    def initialize(sh)
      @sh = sh
      @rcmds = []
      @stdout_data = nil
      @in_rd = nil
      @in_wr = nil
      @out_rd = nil
      @out_wr = nil
      @pipes = []

      @_out = nil
      @_in = nil
      @_in_data = nil
    end

    # @!visibility private
    def __add_running_command(cmd)
      @rcmds << cmd
    end

    # @!visibility private
    def __run(**kwargs)
      extract_opts(**kwargs)

      cmds = @rcmds.map { |r| r.__spawn_arguments(redirection_args: {}) }
      Open3.pipeline_start(*cmds, compile_redirection_args) do |ts|
        # unused
        @in_rd&.close
        @out_wr&.close

        # redirect from :in
        @in_wr&.write(@_in_data) if @_in_data
        @in_wr&.close

        # wait
        ts.map(&:value)

        # redirect to :out
        @stdout_data = @out_rd&.read
        @out_rd&.close
      end

      self
    end

    private

    def extract_opts(**kwargs)
      kwargs.each do |k, v|
        raise ::ArgumentError, format("Unsupported kwarg: %s", k) unless SPECIAL_KWARGS.include?(k.to_sym)
        case k.to_sym
        when :_out
          @_out = v
        when :_in
          @_in = v
        when :_in_data
          @_in_data = v
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

      args
    end
  end
end
