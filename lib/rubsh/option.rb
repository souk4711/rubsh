module Rubsh
  class Option
    # @!attribute [r] k
    # @return [String]
    attr_reader :k

    # @!attribute [r] v
    attr_reader :v

    # .
    private_class_method :new

    # @overload build(option)
    #   @param option [Option]
    #
    # @overload build(name)
    #   @param name [String, Symbol, #to_s]
    #
    # @overload build(name, value)
    #   @param name [String, Symbol, #to_s]
    #   @param value [nil, Boolean, Numeric, String, Symbol, Proc]
    #
    # @return [Option]
    def self.build(*args)
      if args[0].is_a?(Option)
        o = args[0]
        new(o.k, o.v, positional: o.positional?, is_special_kwarg: o.special_kwarg?)
      else
        new(args[0], args[1], positional: args.length < 2)
      end
    end

    # @param k [String, Symbol, #to_s]
    # @param v [nil, Boolean, Numeric, String, Symbol, Proc]
    def initialize(k, v, positional:, is_special_kwarg: nil)
      @is_positional = positional
      @is_special_kwarg = is_special_kwarg.nil? ? false : is_special_kwarg

      if positional
        @k, @v = k.to_s, nil
      else
        case k
        when ::String
          @k, @v = k, v
        when ::Symbol
          if k.to_s[0] == "_"
            @k, @v = k.to_s, v
            @is_special_kwarg = true
          else
            @k, @v = k.to_s.tr("_", "-"), v
          end
        else raise ::ArgumentError, format("unsupported option type `%s (%s)'", k, k.class)
        end
      end
    end

    def positional?
      @is_positional
    end

    def kwarg?
      !positional?
    end

    def special_kwarg?(sk = nil)
      if sk.nil?
        @is_special_kwarg
      else
        @is_special_kwarg && k == sk.to_s
      end
    end
  end
end
