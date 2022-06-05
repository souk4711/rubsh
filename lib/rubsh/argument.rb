module Rubsh
  class Argument
    # @overload initialize(name)
    #   @param name [String, Symbol, #to_s]
    #
    # @overload initialize(name, value)
    #   @param name [String, Symbol, #to_s]
    #   @param value [nil, Boolean, Numeric, String, Symbol, Proc]
    def initialize(*args)
      @name, @value = args[0].to_s, args[1]
      @is_positional = args.length < 2
    end

    # @return [void]
    def value=(value)
      raise ::ArgumentError, "cannot assign a new value for positional argument" if @is_positional
      @value = value
    end

    # @return [nil, String, Array<String>]
    def compile(long_sep: "=", long_prefix: "--")
      return compile_positional_argument(@name) if @is_positional
      compile_option_argument(@name, @value, long_sep: long_sep, long_prefix: long_prefix)
    end

    private

    def compile_positional_argument(name)
      name
    end

    def compile_option_argument(name, value, long_sep:, long_prefix:)
      value = value.call if value.respond_to?(:call)
      return if value.nil?
      return if value.is_a?(::FalseClass)

      if name.length == 1 # short option
        return format("-%s", name) if value.is_a?(::TrueClass)
        format("-%s%s", name, value)
      else # long option
        return format("%s%s", long_prefix, name) if value.is_a?(::TrueClass)
        return [format("%s%s", long_prefix, name), value.to_s] if long_sep.nil?
        format("%s%s%s%s", long_prefix, name, long_sep, value)
      end
    end
  end
end
