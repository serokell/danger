# SPDX-FileCopyrightText: 2023 Serokell <https://serokell.io>
# SPDX-License-Identifier: MPL-2.0

module SerokellDanger
  class Config
    attr_reader :check_name

    
    attr_reader :configure_with


    def initialize(check_name, values, configure_with: nil)
      @check_name = check_name
      @configure_with = configure_with
      @values = values
      freeze
    end

    def [](key)
      key = key.to_sym
      assert_known_key(key)
      @values[key]
    end

    def key?(key)
      @values.key?(key.to_sym)
    end

    def keys
      @values.keys
    end

    def to_h
      @values.dup
    end

    def merge(overrides)
      overrides = overrides.to_h if overrides.is_a?(Config)
      new_values = @values.dup
      overrides.each do |key, value|
        key = key.to_sym
        assert_known_key(key)
        old = @values[key]
        new_values[key] =
          if old.is_a?(Config) && value.is_a?(Hash)
            old.merge(value)
          else
            value
          end
      end
      Config.new(@check_name, new_values, configure_with: @configure_with)
    end
    alias with merge

    def method_missing(name, *args)
      if args.empty? && @values.key?(name)
        @values[name]
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      @values.key?(name) || super
    end

    def inspect
      "#<#{self.class} #{@check_name} #{@values.inspect}>"
    end

    private

    def assert_known_key(key)
      return if @values.key?(key)

      raise ArgumentError,
            "Unknown option `#{key}` for the `#{@check_name}` check. " \
            "Known options: #{@values.keys.sort.join(', ')}."
    end
  end
end
