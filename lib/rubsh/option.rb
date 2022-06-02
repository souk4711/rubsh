module Rubsh
  class Option
    attr_reader :k, :v
    private_class_method :new

    def self.build(k, v = nil)
      return new(k.k, k.v) if k.is_a?(Option)
      new(k, v)
    end

    def initialize(k, v)
      @k, @v = k, v
    end
  end
end
