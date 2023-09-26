RSpec.describe Rubsh do
  describe ".new" do
    it "returns a Shell instance" do
      sh = described_class.new
      expect(sh).to be_a(Rubsh::Shell)
    end
  end
end
