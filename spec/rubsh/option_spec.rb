RSpec.describe Rubsh::Option do
  matcher :build_to do |expected|
    match do |actual|
      actual.k == expected[0] && actual.v == expected[1]
    end
  end

  describe ".build" do
    it "builds from k" do
      expect(described_class.build("k")).to build_to(["k", nil])
      expect(described_class.build(:k)).to build_to([:k, nil])
    end

    it "builds from k, v pair" do
      expect(described_class.build("k", "v")).to build_to(["k", "v"])
      expect(described_class.build(:k, "v")).to build_to([:k, "v"])
    end

    it "builds from Rubsh::Option" do
      from = described_class.build("k", "v")
      expect(described_class.build(from)).to build_to(["k", "v"])
    end
  end
end
