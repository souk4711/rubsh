RSpec.describe Rubsh::RunningPipeline do
  let(:sh) { Rubsh::Shell.new }
  let(:rawsh) { sh.cmd("sh").bake("-c") }
  let(:ls) { sh.cmd("ls") }
  let(:wc) { sh.cmd("wc") }
  let(:cat) { sh.cmd("cat") }
  let(:echo) { sh.cmd("echo").bake("-n") }
  let(:less) { sh.cmd("less") }

  describe "#call_with" do
    describe "special kwargs" do
      describe ":_in" do
        it "specifies an argument for the process to use as its standard input" do
          f = File.join(__dir__, "command_spec.rb")
          r = sh.pipeline(_in: f) do |pipeline|
            cat.call_with(f, _pipeline: pipeline)
            less.call_with(_pipeline: pipeline)
          end
          expect(r.stdout_data).to eq(File.read(f))
        end
      end

      describe ":_in_data" do
        it "specifies an argument for the process to use as its standard input data" do
          r = sh.pipeline(_in_data: "hello world") do |pipeline|
            cat.call_with(_pipeline: pipeline)
            wc.call_with("-c", _pipeline: pipeline)
          end
          expect(r.stdout_data).to eq("11\n")
        end
      end

      describe ":_out" do
        it "redirects to :_out " do
          Dir::Tmpname.create("rubsh-") do |filename|
            r = sh.pipeline(_out: filename) do |pipeline|
              echo.call_with("out", _pipeline: pipeline)
              wc.call_with("-c", _pipeline: pipeline)
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
              rawsh.call_with("echo -n err >&2", _pipeline: pipeline)
              wc.call_with("-c", _pipeline: pipeline)
            end
            expect(File.read(filename)).to eq("err")
            expect(r.stderr_data).to eq("")
            expect(r.stdout_data).to eq("0\n")
          end
        end
      end

      describe ":_ok_code" do
        it "doesn't raise a CommandReturnFailureError error even command execute failed" do
          r = sh.pipeline(_ok_code: 0..2) do |pipeline|
            ls.call_with("/some/non-existant/folder", _pipeline: pipeline)
          end
          expect(r.exit_code).to eq(2)
        end
      end
    end

    describe "exceptions" do
      it "raises a CommandNotFoundError error when command not exists" do
        expect {
          sh.pipeline do |pipeline|
            sh.cmd("rubsh-commandnotfound").call_with(_pipeline: pipeline)
          end
        }.to raise_error(Rubsh::Exceptions::CommandNotFoundError)
      end

      it "raises a CommandReturnFailureError error when command execute failed" do
        expect {
          sh.pipeline do |pipeline|
            ls.call_with("/some/non-existant/folder", _pipeline: pipeline)
          end
        }.to raise_error(Rubsh::Exceptions::CommandReturnFailureError)
      end
    end
  end
end
