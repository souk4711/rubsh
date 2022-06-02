RSpec.describe Rubsh::Shell do
  describe "#cmd" do
    it "returns a Command instance" do
      ls = subject.cmd("ls")
      expect(ls).to be_a(Rubsh::Command)
    end
  end

  describe "#pipeline" do
    it "returns a RunningPipeline instance" do
      r = subject.pipeline do |pipeline|
        subject.cmd("echo").call_with("hello world", _pipeline: pipeline)
        subject.cmd("wc").call_with("-c", _pipeline: pipeline)
      end
      expect(r).to be_a(Rubsh::RunningPipeline)
      expect(r.stdout_data).to eq("12\n")
    end
  end
end
