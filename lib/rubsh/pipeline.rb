module Rubsh
  class Pipeline
    def initialize(sh)
      @sh = sh
      @rcmds = []
    end

    def call
      rcmds = @rcmds
      pipes = (1...rcmds.length).map { IO.pipe }

      rcmds.each_with_index do |rcmd, idx|
        previous_rd, _previous_wr = idx.zero? ? [$stdin, nil] : pipes[idx - 1]
        _rd, wr = idx == rcmds.length - 1 ? [nil, $stdout] : pipes[idx]
        rcmd.run_in_pipeline(in: previous_rd.fileno, out: wr.fileno)
      end.each_with_index do |rcmd, idx|
        rcmd.wait
        _rd, wr = idx == rcmds.length - 1 ? [nil, nil] : pipes[idx]
        wr&.close
      end

      self
    end

    def add_running_command(cmd)
      @rcmds << cmd
    end
  end
end
