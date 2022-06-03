RSpec.describe Rubsh::Shell do
  let(:wc) { subject.cmd("wc") }
  let(:cat) { subject.cmd("cat") }
  let(:echo) { subject.cmd("echo").bake("-n") }
  let(:less) { subject.cmd("less") }

  describe "#cmd" do
    it "returns a Command instance" do
      ls = subject.cmd("ls")
      expect(ls).to be_a(Rubsh::Command)
    end
  end

  describe "#pipeline" do
    it "returns a RunningPipeline instance" do
      r = subject.pipeline do |pipeline|
        echo.call_with("-n", "hello world", _pipeline: pipeline)
        wc.call_with("-c", _pipeline: pipeline)
      end
      expect(r).to be_a(Rubsh::RunningPipeline)
      expect(r.stdout_data).to eq("11\n")
    end

    describe "special kwargs" do
      describe ":_in" do
        it "specifies an argument for the process to use as its standard input" do
          f = File.join(__dir__, "command_spec.rb")
          r = subject.pipeline(_in: f) do |pipeline|
            cat.call_with(f, _pipeline: pipeline)
            less.call_with(_pipeline: pipeline)
          end
          expect(r.stdout_data).to eq(File.read(f))
        end
      end

      describe ":_in_data" do
        it "specifies an argument for the process to use as its standard input data" do
          r = subject.pipeline(_in_data: "hello world") do |pipeline|
            cat.call_with(_pipeline: pipeline)
            wc.call_with("-c", _pipeline: pipeline)
          end
          expect(r.stdout_data).to eq("11\n")
        end
      end

      describe ":_out" do
        it "redirects to :_out " do
          Dir::Tmpname.create("rubsh-") do |filename|
            r = subject.pipeline(_out: filename) do |pipeline|
              echo.call_with("out", _pipeline: pipeline)
              wc.call_with("-c", _pipeline: pipeline)
            end
            expect(r.stdout_data).to eq("")
            expect(File.read(filename)).to eq("3\n")
          end
        end
      end
    end
  end
end
