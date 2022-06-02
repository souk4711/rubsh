RSpec.describe Rubsh::Command do
  let(:sh) { Rubsh::Shell.new }
  let(:rawsh) { described_class.new(sh, "sh").bake("-c") }
  let(:ls) { described_class.new(sh, "ls") }
  let(:cat) { described_class.new(sh, "cat") }
  let(:env) { described_class.new(sh, "env") }
  let(:pwd) { described_class.new(sh, "pwd") }
  let(:echo) { described_class.new(sh, "echo") }
  let(:sleep) { described_class.new(sh, "sleep") }

  describe "#call_with" do
    it "returns a RunningCommand instance" do
      expect(ls.call_with).to be_a(Rubsh::RunningCommand)
    end

    it "raises a CommandNotFoundError error when command not exists" do
      expect {
        described_class.new(sh, "rubsh-commandnotfound").call_with
      }.to raise_error(Rubsh::Exceptions::CommandNotFoundError)
    end

    it "raises a CommandReturnFailureError error when command execute failed" do
      expect {
        ls.call_with("/some/non-existant/folder")
      }.to raise_error(Rubsh::Exceptions::CommandReturnFailureError)
    end

    it "raises a CommandTimeoutError error when command execute timeout" do
      expect {
        sleep.call_with(4, _timeout: 1)
      }.to raise_error(Rubsh::Exceptions::CommandTimeoutError)
    end

    describe "with :_out" do
      it "redirects to :_out " do
        Dir::Tmpname.create("rubsh-") do |filename|
          r = echo.call_with("out", _out: filename)
          expect(r.stdout_data).to eq("")
          expect(File.read(filename)).to eq("out\n")
        end
      end
    end

    describe "with :_err" do
      it "redirects to :_err " do
        Dir::Tmpname.create("rubsh-") do |filename|
          r = rawsh.call_with("echo err >&2", _err: filename)
          expect(r.stderr_data).to eq("")
          expect(File.read(filename)).to eq("err\n")
        end
      end
    end

    describe "with :_err_to_out" do
      it "duplicates the file descriptor bound to the process’s STDOUT also to STDERR." do
        Dir::Tmpname.create("rubsh-") do |filename|
          r = rawsh.call_with("echo out; echo err >&2", _out: filename, _err_to_out: true)
          expect(r.stdout_data).to eq("")
          expect(r.stderr_data).to eq("")
          expect(File.read(filename)).to eq("out\nerr\n")
        end
      end
    end

    describe "with :_bg" do
      it "doesn't block" do
        t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        r = sleep.call_with(1, _bg: true)
        t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        expect(t2 - t1).to be < 0.1

        r.wait
        t3 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        expect(t3 - t1).to be > 1.0
      end
    end

    describe "with :_env" do
      it "by default, the calling process’s environment variables are used" do
        r = env.call_with
        expect(r.stdout_data).to include("SHELL=")
      end

      it "with a dictionary, only defined environment variables is accessible" do
        r = env.call_with(_env: {})
        expect(r.stdout_data).to eq("")

        r = env.call_with(_env: {RUBSH_ENV: 1})
        expect(r.stdout_data).to eq("RUBSH_ENV=1\n")
      end
    end

    describe "with :_timeout" do
      it "raises a CommandTimeoutError error when command execute timeout" do
        expect {
          sleep.call_with(4, _timeout: 1)
        }.to raise_error(Rubsh::Exceptions::CommandTimeoutError)
      end
    end

    describe "with :_cwd" do
      it "specifies urrent working directory of the process" do
        r = pwd.call_with(_cwd: "/")
        expect(r.stdout_data).to eq("/\n")
      end
    end

    describe "with :_ok_code" do
      it "doesn't raise a CommandReturnFailureError error even command execute failed" do
        r = ls.call_with("/some/non-existant/folder", _ok_code: [0, 2])
        expect(r.exit_code).to eq(2)
      end
    end

    describe "with :_in" do
      it "specifies an argument for the process to use as its standard input" do
        f = File.join(__dir__, "command_spec.rb")
        r = cat.call_with(_in: f)
        expect(r.stdout_data).to eq(File.read(f))
      end
    end

    describe "with :_no_out" do
      it " disables STDOUT being internally stored." do
        r = echo.call_with("out", _no_out: true)
        expect(r.stdout_data).to eq("")
      end
    end

    describe "with :_no_err" do
      it "disables STDERR being internally stored" do
        r = echo.call_with("out", _no_err: true)
        expect(r.stderr_data).to eq("")
      end
    end

    describe "with :_long_sep" do
      it "specifies the character(s) that separate a program’s long argument’s key from the value" do
      end
    end

    describe "with :_long_prefix" do
      it "specifies the character(s) that prefix a long argument for the program being run" do
      end
    end

    describe "with :_pipeline" do
    end
  end

  describe "#bake" do
    it "returns a new instance" do
      lla = ls.bake("-la")
      expect(lla).to be_a(described_class)
      expect(lla).not_to eq(ls)
    end
  end
end
