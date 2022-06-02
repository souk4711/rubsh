module Rubsh
  class Option
    attr_reader :k, :v
    private_class_method :new

    def self.build(*args)
      if args[0].is_a?(Option)
        o = args[0]
        new(o.k, o.v, positional: o.positional?)
      else
        new(args[0], args[1], positional: args.length < 2)
      end
    end

    def initialize(k, v, positional:)
      @k, @v = k, v
      @is_positional = positional
    end

    def positional?
      @is_positional
    end
  end
end
