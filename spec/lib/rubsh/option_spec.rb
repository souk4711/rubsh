RSpec.describe Rubsh::Option do
  matcher :build_to do |expected|
    match do |actual|
      actual.k == expected[0] && actual.v == expected[1]
    end
  end

  describe ".build" do
    it "builds from k" do
      expect(described_class.build(:k)).to build_to(["k", nil])
      expect(described_class.build("k")).to build_to(["k", nil])
    end

    it "builds from k, v pair" do
      expect(described_class.build(:k, "v")).to build_to(["k", "v"])
      expect(described_class.build("k", "v")).to build_to(["k", "v"])
    end

    it "builds from Rubsh::Option" do
      from = described_class.build("k", "v")
      expect(described_class.build(from)).to build_to(["k", "v"])
    end

    it "convert kwargs when it's a Symbol" do
      o = described_class.build(:group_directories_first, "v")
      expect(o).to build_to(["group-directories-first", "v"])
      expect(o).to be_kwarg
      expect(o).not_to be_special_kwarg
    end

    it "donot convert kwargs when it's a String" do
      o = described_class.build("group_directories_first", "v")
      expect(o).to build_to(["group_directories_first", "v"])
      expect(o).to be_kwarg
      expect(o).not_to be_special_kwarg

      o = described_class.build("_env", "v")
      expect(o).to build_to(["_env", "v"])
      expect(o).to be_kwarg
      expect(o).not_to be_special_kwarg
    end

    it "donot convert special kwargs" do
      o = described_class.build(:_env, "v")
      expect(o).to build_to(["_env", "v"])
      expect(o).to be_kwarg
      expect(o).to be_special_kwarg
      expect(o).to be_special_kwarg(:_env)
    end
  end
end
