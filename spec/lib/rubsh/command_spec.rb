RSpec.describe Rubsh::Command do
  matcher :be_called_with_arguments do |expected|
    match do |actual|
      actual.__send__(:compile_cmd_args) == expected
    end
  end

  let(:sh) { Rubsh::Shell.new }
  let(:rawsh) { described_class.new(sh, "sh").bake("-c") }
  let(:ls) { described_class.new(sh, "ls") }
  let(:cat) { described_class.new(sh, "cat") }
  let(:env) { described_class.new(sh, "env") }
  let(:git) { described_class.new(sh, "git") }
  let(:pwd) { described_class.new(sh, "pwd") }
  let(:echo) { described_class.new(sh, "echo").bake("-n") }
  let(:sleep) { described_class.new(sh, "sleep") }

  it "supports use absolute path to set prog" do
    expect {
      described_class.new(sh, RSPEC_ROOT.join("fixtures/bin/rubsh-83aciz.sh"))
    }.to_not raise_error
  end

  describe "#call" do
    it "returns a RunningCommand instance" do
      expect(ls.call).to be_a(Rubsh::RunningCommand)
    end

    describe "resolves arguments" do
      it "positional argument" do
        expect(ls.call("-l")).to be_called_with_arguments(["-l"])
        expect(ls.call("-l", "--all")).to be_called_with_arguments(["-l", "--all"])
      end

      it "short option argument" do
        expect(ls.call(A: nil)).to be_called_with_arguments([])
        expect(ls.call(A: false)).to be_called_with_arguments([])
        expect(ls.call(A: true)).to be_called_with_arguments(["-A"])
        expect(ls.call(A: proc { true })).to be_called_with_arguments(["-A"])
      end

      it "long option argument" do
        expect(ls.call(all: nil)).to be_called_with_arguments([])
        expect(ls.call(all: false)).to be_called_with_arguments([])
        expect(ls.call(all: true)).to be_called_with_arguments(["--all"])
        expect(ls.call(all: proc { true })).to be_called_with_arguments(["--all"])
        expect(ls.call(almost_all: true)).to be_called_with_arguments(["--almost-all"])
      end

      it "positional & option argument" do
        expect(ls.call("-l", A: true, almost_all: true)).to be_called_with_arguments(["-l", "-A", "--almost-all"])
      end

      it "with String, Symbol, Hash, etc." do
        expect(git.call("status")).to be_called_with_arguments(["status"])
        expect(git.call(:status)).to be_called_with_arguments(["status"])
        expect(git.call(:status, "-v")).to be_called_with_arguments(["status", "-v"])
        expect(git.call(:status, v: true)).to be_called_with_arguments(["status", "-v"])
        expect(git.call(:status, {v: true})).to be_called_with_arguments(["status", "-v"])
        expect(git.call(:status, {v: true}, "--", ".")).to be_called_with_arguments(["status", "-v", "--", "."])
        expect(git.call(:status, {v: proc { true }, short: true}, "--", ".")).to be_called_with_arguments(["status", "-v", "--short", "--", "."])
        expect(git.call(:status, {untracked_files: "normal"}, "--", ".")).to be_called_with_arguments(["status", "--untracked-files=normal", "--", "."])
      end

      it "overwrites kwargs" do
        expect(git.call(:status, {v: true})).to be_called_with_arguments(["status", "-v"])
        expect(git.call(:status, {v: true}, v: false)).to be_called_with_arguments(["status"])
        expect(git.bake(:status, {v: true}).call(v: false)).to be_called_with_arguments(["status"])
        expect(git.bake(:status, {v: true}).call("v" => false)).to be_called_with_arguments(["status"])
      end

      it "overwrites special kwargs" do
        r = env.bake(_env: {RUBSH_ENV_BAKE: 1}).call(_env: {RUBSH_ENV_CALL: 1})
        expect(r.stdout_data).to eq("RUBSH_ENV_CALL=1\n")
      end
    end

    describe "special kwargs" do
      describe ":_out" do
        it "redirects to :_out " do
          Dir::Tmpname.create("rubsh-") do |filename|
            r = echo.call("out", _out: filename)
            expect(r.stdout_data).to eq("")
            expect(File.read(filename)).to eq("out")
          end
        end
      end

      describe ":_err" do
        it "redirects to :_err " do
          Dir::Tmpname.create("rubsh-") do |filename|
            r = rawsh.call("echo -n err >&2", _err: filename)
            expect(r.stderr_data).to eq("")
            expect(File.read(filename)).to eq("err")
          end
        end
      end

      describe ":_err_to_out" do
        it "duplicates the file descriptor bound to the process’s STDOUT also to STDERR." do
          Dir::Tmpname.create("rubsh-") do |filename|
            r = rawsh.call("echo out; echo err >&2", _out: filename, _err_to_out: true)
            expect(r.stdout_data).to eq("")
            expect(r.stderr_data).to eq("")
            expect(File.read(filename)).to eq("out\nerr\n")
          end
        end
      end

      describe ":_bg" do
        it "doesn't block" do
          t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          r = sleep.call(1, _bg: true)
          t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          expect(t2 - t1).to be < 0.1

          r.wait
          t3 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          expect(t3 - t1).to be > 1.0
        end
      end

      describe ":_env" do
        it "by default, the calling process’s environment variables are used" do
          r = env.call
          expect(r.stdout_data).to include("HOME=")
        end

        it "with a dictionary, only defined environment variables is accessible" do
          r = env.call(_env: {})
          expect(r.stdout_data).to eq("")

          r = env.call(_env: {RUBSH_ENV: 1})
          expect(r.stdout_data).to eq("RUBSH_ENV=1\n")
        end
      end

      describe ":_timeout" do
        it "raises a CommandTimeoutError error when command execute timeout" do
          expect {
            sleep.call(4, _timeout: 1)
          }.to raise_error(Rubsh::Exceptions::CommandTimeoutError)
        end
      end

      describe ":_cwd" do
        it "specifies urrent working directory of the process" do
          r = pwd.call(_cwd: "/")
          expect(r.stdout_data).to eq("/\n")
        end
      end

      describe ":_ok_code" do
        it "doesn't raise a CommandReturnFailureError error even command execute failed" do
          r = ls.call("/some/non-existant/folder", _ok_code: [0, 2])
          expect(r.exit_code).to eq(2)
          expect(r.ok?).to eq(true)
        end
      end

      describe ":_out_bufsize" do
        it "line buffered" do
          r = []
          echo.call("out1\nout2\nout3", _capture: ->(stdout, _) {
            r << stdout
          })
          expect(r).to eq(["out1\n", "out2\n", "out3"])
        end

        it "custom bufsize" do
          r = []
          echo.call("out1", _out_bufsize: 3, _capture: ->(stdout, _) {
            r << stdout
          })
          expect(r).to eq(["out", "1"])
        end
      end

      describe ":_err_bufsize" do
        it "line buffered" do
          r = []
          echo.call("err1\nerr2\nerr3", _out: [:child, :err], _capture: ->(_, stderr) {
            r << stderr
          })
          expect(r).to eq(["err1\n", "err2\n", "err3"])
        end

        it "custom bufsize" do
          r = []
          echo.call("err1", _err_bufsize: 3, _out: [:child, :err], _capture: ->(_, stderr) {
            r << stderr
          })
          expect(r).to eq(["err", "1"])
        end
      end

      describe ":_no_out" do
        it "disables STDOUT being internally stored" do
          r = echo.call("out")
          expect(r.stdout_data).to eq("out")

          r = echo.call("out", _no_out: true)
          expect(r.stdout_data).to eq("")
        end
      end

      describe ":_no_err" do
        it "disables STDERR being internally stored" do
          r = rawsh.call("echo err >&2")
          expect(r.stderr_data).to eq("err\n")

          r = rawsh.call("echo err >&2", _no_err: true)
          expect(r.stderr_data).to eq("")
        end
      end

      describe ":_in" do
        it "specifies an argument for the process to use as its standard input" do
          r = cat.call(_in: __FILE__)
          expect(r.stdout_data).to eq(File.read(__FILE__))
        end
      end

      describe ":_in_data" do
        it "specifies an argument for the process to use as its standard input data" do
          r = cat.call(_in_data: "hello")
          expect(r.stdout_data).to eq("hello")
        end
      end

      describe ":_long_sep" do
        it "specifies the character(s) that separate a program’s long argument’s key from the value" do
        end
      end

      describe ":_long_prefix" do
        it "specifies the character(s) that prefix a long argument for the program being run" do
        end
      end

      describe ":_pipeline" do
      end
    end

    describe "exceptions" do
      it "raises a CommandNotFoundError error when command not exists" do
        expect {
          described_class.new(sh, "rubsh-commandnotfound").call
        }.to raise_error(Rubsh::Exceptions::CommandNotFoundError)
      end

      it "raises a CommandReturnFailureError error when command execute failed" do
        expect {
          ls.call("/some/non-existant/folder")
        }.to raise_error(Rubsh::Exceptions::CommandReturnFailureError)

        ls_bg = ls.call("/some/non-existant/folder", _bg: true)
        expect { ls_bg.wait }.to raise_error(Rubsh::Exceptions::CommandReturnFailureError)
        expect(ls_bg.ok?).to eq(false)
      end

      it "raises a CommandTimeoutError error when command execute timeout" do
        expect {
          sleep.call(4, _timeout: 1)
        }.to raise_error(Rubsh::Exceptions::CommandTimeoutError)
      end
    end
  end

  describe "#bake" do
    it "returns a new instance" do
      lla = ls.bake("-la")
      expect(lla).to be_a(described_class)
      expect(lla).not_to eq(ls)
    end

    it "supports kwargs" do
      lla = ls.bake("-l", group_directories_first: true).bake("-A")
      expect(lla.call("/")).to be_called_with_arguments(["-l", "--group-directories-first", "-A", "/"])
    end

    it "supports specifies kwargs" do
      r = env.bake(_env: {RUBSH_ENV: 1}).call
      expect(r.stdout_data).to eq("RUBSH_ENV=1\n")
    end
  end
end
