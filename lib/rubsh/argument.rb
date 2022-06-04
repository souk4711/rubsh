module Rubsh
  class Argument
    def initialize(*args)
      @name, @value = args
      @is_positional = args.length < 2
    end

    def compile(long_sep: "=", long_prefix: "--")
      return compile_positional_argument(@name) if @is_positional
      compile_option_argument(@name, @value, long_sep: long_sep, long_prefix: long_prefix)
    end

    private

    def compile_positional_argument(name)
      name.to_s
    end

    def compile_option_argument(name, value, long_sep:, long_prefix:)
      value = value.call if value.respond_to?(:call)
      return if value.nil?
      return if value.is_a?(::FalseClass)

      if name.to_s.length == 1 # short option
        return format("-%s", name) if value.is_a?(::TrueClass)
        format("-%s%s", name, value)
      else # long option
        if name.is_a?(::Symbol)
          name = name.to_s.tr("_", "-")
        elsif name.is_a?(::String)
          nil
        else
          raise ::ArgumentError, format("unsupported argument type `%s (%s)'", name, name.class)
        end

        return format("%s%s", long_prefix, name) if value.is_a?(::TrueClass)
        return [format("%s%s", long_prefix, name), value.to_s] if long_sep.nil?
        format("%s%s%s%s", long_prefix, name, long_sep, value)
      end
    end
  end
end
