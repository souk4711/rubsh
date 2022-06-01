module Rubsh
  class RunningPipeline
    USED_RESERVED_WORDS = %i[
      _out
      _in
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
    end

    def call(**kwargs)
      extract_opts(**kwargs)
      spawn
      wait
      self
    end

    def add_running_command(cmd)
      @rcmds << cmd
    end

    private

    def extract_opts(**kwargs)
      kwargs.each do |k, v|
        raise ::ArgumentError, format("Unsupported kwarg: %s", k) unless USED_RESERVED_WORDS.include?(k.to_sym)
        case k.to_sym
        when :out
          @_out = v
        when :in
          @_in = v
        end
      end
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
        args[:out] = @_out
      else
        @out_rd, @out_wr = ::IO.pipe
        args[:out] = @out_wr.fileno
      end

      args
    end

    def spawn
      @pipes = (1...@rcmds.length).map { ::IO.pipe }
      pipes_filenos = @pipes.map { |pipe| pipe.map(&:fileno) }

      redirection_args = compile_redirection_args
      @rcmds.each_with_index do |rcmd, idx|
        previous_rd, _ = idx.zero? ? [redirection_args[:in], nil] : pipes_filenos[idx - 1]
        _, wr = idx == @rcmds.length - 1 ? [nil, redirection_args[:out]] : pipes_filenos[idx]
        rcmd.run_in_pipeline(in: previous_rd, out: wr)
      end
    ensure
      @in_rd&.close
      @out_wr&.close
    end

    def wait
      @rcmds.each_with_index do |rcmd, idx|
        rcmd.wait
        _rd, wr = idx == @rcmds.length - 1 ? [nil, nil] : @pipes[idx]
        wr&.close
      end

      @stdout_data = @out_rd&.read
    ensure
      @in_wr&.close
      @out_rd&.close
    end
  end
end
