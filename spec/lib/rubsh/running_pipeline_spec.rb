RSpec.describe Rubsh::RunningPipeline do
  let(:sh) { Rubsh::Shell.new }
  let(:rawsh) { sh.cmd("sh").bake("-c") }
  let(:ls) { sh.cmd("ls") }
  let(:wc) { sh.cmd("wc") }
  let(:cat) { sh.cmd("cat") }
  let(:env) { sh.cmd("env") }
  let(:pwd) { sh.cmd("pwd") }
  let(:echo) { sh.cmd("echo").bake("-n") }
  let(:less) { sh.cmd("less") }
  let(:sleep) { sh.cmd("sleep") }

  describe "#call" do
    describe "special kwargs" do
      describe ":_in" do
        it "specifies an argument for the process to use as its standard input" do
          r = sh.pipeline(_in: __FILE__) do |pipeline|
            cat.call(__FILE__, _pipeline: pipeline)
            less.call(_pipeline: pipeline)
          end
          expect(r.stdout_data).to eq(File.read(__FILE__))
        end
      end

      describe ":_in_data" do
        it "specifies an argument for the process to use as its standard input data" do
          r = sh.pipeline(_in_data: "hello world") do |pipeline|
            cat.call(_pipeline: pipeline)
            wc.call("-c", _pipeline: pipeline)
          end
          expect(r.stdout_data).to eq("11\n")
        end
      end

      describe ":_out" do
        it "redirects to :_out " do
          Dir::Tmpname.create("rubsh-") do |filename|
            r = sh.pipeline(_out: filename) do |pipeline|
              echo.call("out", _pipeline: pipeline)
              wc.call("-c", _pipeline: pipeline)
            end
            expect(File.read(filename)).to eq("3\n")
            expect(r.stdout_data).to eq("")
          end
        end
      end

      describe ":_err" do
        it "redirects to :_err " do
          Dir::Tmpname.create("rubsh-") do |filename|
            r = sh.pipeline(_err: filename) do |pipeline|
              rawsh.call("echo -n err >&2", _pipeline: pipeline)
              wc.call("-c", _pipeline: pipeline)
            end
            expect(File.read(filename)).to eq("err")
            expect(r.stderr_data).to eq("")
            expect(r.stdout_data).to eq("0\n")
          end
        end
      end

      describe ":_err_to_out" do
        it "duplicates the file descriptor bound to the process’s STDOUT also to STDERR." do
          Dir::Tmpname.create("rubsh-") do |filename|
            r = sh.pipeline(_out: filename, _err_to_out: true) do |pipeline|
              rawsh.call("echo out; echo err >&2", _pipeline: pipeline)
            end
            expect(r.stdout_data).to eq("")
            expect(r.stderr_data).to eq("")
            expect(File.read(filename)).to eq("out\nerr\n")
          end
        end
      end

      describe ":_bg" do
        it "doesn't block" do
          t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          r = sh.pipeline(_bg: true) do |pipeline|
            sleep.call(1, _pipeline: pipeline)
          end
          t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          expect(t2 - t1).to be < 0.1

          r.wait
          t3 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          expect(t3 - t1).to be > 1.0
        end
      end

      describe ":_env" do
        it "with a dictionary, only defined environment variables is accessible" do
          r = sh.pipeline(_env: {}) do |pipeline|
            env.call(_pipeline: pipeline)
          end
          expect(r.stdout_data).to eq("")

          r = sh.pipeline(_env: {RUBSH_ENV: 1}) do |pipeline|
            env.call(_pipeline: pipeline)
          end
          expect(r.stdout_data).to eq("RUBSH_ENV=1\n")
        end
      end

      describe ":_cwd" do
        it "specifies urrent working directory of the process" do
          r = sh.pipeline(_cwd: "/") do |pipeline|
            pwd.call(_cwd: "/home", _pipeline: pipeline)
          end
          expect(r.stdout_data).to eq("/\n")

          r = sh.pipeline do |pipeline|
            pwd.call(_cwd: "/home", _pipeline: pipeline)
          end
          expect(r.stdout_data).to eq("/home\n")
        end
      end

      describe ":_ok_code" do
        it "doesn't raise a CommandReturnFailureError error even command execute failed" do
          r = sh.pipeline(_ok_code: 0..2) do |pipeline|
            ls.call("/some/non-existant/folder", _pipeline: pipeline)
          end
          expect(r.exit_code).to eq(2)
          expect(r.ok?).to eq(true)
        end
      end

      describe ":_out_bufsize" do
        it "line buffered" do
          r = []
          sh.pipeline(_capture: ->(stdout, _) { r << stdout }) do |pipeline|
            echo.call("out1\nout2\nout3", _pipeline: pipeline)
          end
          expect(r).to eq(["out1\n", "out2\n", "out3"])
        end
      end

      describe ":_err_bufsize" do
        it "line buffered" do
          r = []
          sh.pipeline(_out: [:child, :err], _capture: ->(_, stderr) { r << stderr }) do |pipeline|
            echo.call("err1\nerr2\nerr3", _pipeline: pipeline)
          end
          expect(r).to eq(["err1\n", "err2\n", "err3"])
        end
      end

      describe ":_no_out" do
        it "disables STDOUT being internally stored" do
          r = sh.pipeline do |pipeline|
            echo.call("out", _pipeline: pipeline)
          end
          expect(r.stdout_data).to eq("out")

          r = sh.pipeline(_no_out: true) do |pipeline|
            echo.call("out", _pipeline: pipeline)
          end
          expect(r.stdout_data).to eq("")
        end
      end

      describe ":_no_err" do
        it "disables STDERR being internally stored" do
          r = sh.pipeline do |pipeline|
            rawsh.call("echo err >&2", _pipeline: pipeline)
          end
          expect(r.stderr_data).to eq("err\n")

          r = sh.pipeline(_no_err: true) do |pipeline|
            rawsh.call("echo err >&2", _pipeline: pipeline)
          end
          expect(r.stderr_data).to eq("")
        end
      end
    end

    describe "exceptions" do
      it "raises a CommandNotFoundError error when command not exists" do
        expect {
          sh.pipeline do |pipeline|
            sh.cmd("rubsh-commandnotfound").call(_pipeline: pipeline)
          end
        }.to raise_error(Rubsh::Exceptions::CommandNotFoundError)
      end

      it "raises a CommandReturnFailureError error when command execute failed" do
        expect {
          sh.pipeline do |pipeline|
            ls.call("/some/non-existant/folder", _pipeline: pipeline)
          end
        }.to raise_error(Rubsh::Exceptions::CommandReturnFailureError)

        ls_bg =
          sh.pipeline(_bg: true) do |pipeline|
            ls.call("/some/non-existant/folder", _pipeline: pipeline)
          end
        expect { ls_bg.wait }.to raise_error(Rubsh::Exceptions::CommandReturnFailureError)
        expect(ls_bg.ok?).to eq(false)
      end

      it "raises a CommandTimeoutError error when command execute timeout" do
        expect {
          sh.pipeline(_timeout: 1) do |pipeline|
            sleep.call(4, _pipeline: pipeline)
          end
        }.to raise_error(Rubsh::Exceptions::CommandTimeoutError)
      end
    end
  end
end
