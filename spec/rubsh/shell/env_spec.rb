RSpec.describe Rubsh::Shell::Env do
  let(:sh) { Rubsh::Shell.new }

  describe "#path" do
    it "lookups prog in #path" do
      expect { sh.cmd("rubsh-83aciz.sh") }.to raise_error(Rubsh::Exceptions::CommandNotFoundError)

      sh.env.path = RSPEC_ROOT.join("fixtures/bin/")
      expect { sh.cmd("rubsh-83aciz.sh") }.to_not raise_error
      expect { sh.cmd("ls") }.to raise_error(Rubsh::Exceptions::CommandNotFoundError)
    end
  end
end
