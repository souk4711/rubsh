RSpec.describe Rubsh::Command do
  let(:sh) { Rubsh::Shell.new }
  subject(:ls) { described_class.new(sh, "ls") }
  subject(:sleep) { described_class.new(sh, "sleep") }

  describe ".call_with" do
    it "returns a RunningCommand instance" do
      expect(ls.call_with()).to be_a(Rubsh::RunningCommand)
    end

    it "raises a CommandNotFoundError error when command not exists" do
      expect {
        described_class.new(sh, "rubsh-commandnotfound").call
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
  end

  describe ".bake" do
    it "returns a new instance" do
      lla = ls.bake("-la")
      expect(lla).to be_a(described_class)
      expect(lla).not_to eq(ls)
    end
  end
end
