RSpec.describe Rubsh::Argument do
  matcher :compiled_to do |expected|
    match { |actual| actual.compile == expected }
  end

  describe "positional argument" do
    it "supports name use String type" do
      expect(described_class.new("hello")).to compiled_to("hello")
    end

    it "supports name use Symbol type" do
      expect(described_class.new(:hello)).to compiled_to("hello")
    end

    it "supports name use Number type" do
      expect(described_class.new(65536)).to compiled_to("65536")
      expect(described_class.new(6.553)).to compiled_to("6.553")
    end
  end

  describe "short option argument" do
    it "supports name use String type" do
      expect(described_class.new("o", "hello")).to compiled_to("-ohello")
    end

    it "supports name use Symbol type" do
      expect(described_class.new(:o, "hello")).to compiled_to("-ohello")
    end

    it "supports value use FalseClass type" do
      expect(described_class.new("o", false)).to compiled_to(nil)
    end

    it "supports value use TrueClass type" do
      expect(described_class.new("o", true)).to compiled_to("-o")
    end

    it "supports value use String type" do
      expect(described_class.new("o", "hello")).to compiled_to("-ohello")
    end

    it "supports value use Symbol type" do
      expect(described_class.new("o", :hello)).to compiled_to("-ohello")
    end

    it "supports value use Number type" do
      expect(described_class.new("o", 12345)).to compiled_to("-o12345")
      expect(described_class.new("o", 1.234)).to compiled_to("-o1.234")
    end

    it "supports value use Proc type" do
      expect(described_class.new("o", proc {})).to compiled_to(nil)
      expect(described_class.new("o", proc { false })).to compiled_to(nil)
      expect(described_class.new("o", proc { true })).to compiled_to("-o")
      expect(described_class.new("o", proc { "hello" })).to compiled_to("-ohello")
    end
  end

  describe "long option argument" do
    it "supports name use String type, keep original name" do
      expect(described_class.new("output", "hello")).to compiled_to("--output=hello")
      expect(described_class.new("output-file", "hello")).to compiled_to("--output-file=hello")
    end

    it "supports name use Symbol type" do
      expect(described_class.new(:output, "hello")).to compiled_to("--output=hello")
      expect(described_class.new(:"output-file", "hello")).to compiled_to("--output-file=hello")
    end

    it "supports value use FalseClass type" do
      expect(described_class.new("output", false)).to compiled_to(nil)
    end

    it "supports value use TrueClass type" do
      expect(described_class.new("output", true)).to compiled_to("--output")
    end

    it "supports value use String type" do
      expect(described_class.new("output", "hello")).to compiled_to("--output=hello")
    end

    it "supports value use Symbol type" do
      expect(described_class.new("output", :hello)).to compiled_to("--output=hello")
    end

    it "supports value use Number type" do
      expect(described_class.new("output", 1.234)).to compiled_to("--output=1.234")
    end

    it "supports value use Proc type" do
      expect(described_class.new("output", proc {})).to compiled_to(nil)
      expect(described_class.new("output", proc { false })).to compiled_to(nil)
      expect(described_class.new("output", proc { true })).to compiled_to("--output")
      expect(described_class.new("output", proc { "hello" })).to compiled_to("--output=hello")
    end
  end

  describe "#compile" do
    describe "with :long_sep" do
      subject { described_class.new("output", "hello") }

      it "supports nil, keep the name to be separate from its value" do
        expect(subject.compile(long_sep: nil)).to eq(["--output", "hello"])
      end

      it "supports ''" do
        expect(subject.compile(long_sep: "")).to eq("--outputhello")
      end

      it "supports ' '" do
        expect(subject.compile(long_sep: " ")).to eq("--output hello")
      end

      it "supports ':'" do
        expect(subject.compile(long_sep: ":")).to eq("--output:hello")
      end
    end

    describe "with :long_prefix" do
      subject { described_class.new("output", "hello") }

      it "supports '-'" do
        expect(subject.compile(long_prefix: "-")).to eq("-output=hello")
      end
    end
  end
end
