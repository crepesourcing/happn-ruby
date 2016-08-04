module Happn
  class Event

    def initialize(args)
      @meta = deep_underscore_keys(args.fetch("meta"))
      @data = deep_underscore_keys(args.fetch("data"))
    end

    def data
      @data
    end

    def user_metadata
      @data[:user_metadata]
    end

    def changes
      @data[:changes]
    end

    def associations
      @data[:associations]
    end

    def timestamp
      @meta[:timestamp].to_time
    end

    def id
      @meta[:id]
    end

    def name
      @meta[:name]
    end

    def status
      @meta[:status]
    end

    def kind
      @meta[:kind]
    end

    def emitter
      @meta[:emitter]
    end

    def change_after(attribute_name)
      changes[attribute_name.to_sym].try(:last)
    end

    def change_before(attribute_name)
      changes[attribute_name.to_sym].try(:first)
    end

    private

    def underscore_key(key)
      underscore(key).to_sym
    end

    def deep_underscore_keys(value)
      case value
        when Array
          value.map(&method(:deep_underscore_keys))
        when Hash
          Hash[value.map { |key, value| [underscore_key(key), deep_underscore_keys(value)] }]
        else
          value
       end
    end

    def underscore(camel_cased_word)
      camel_cased_word.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
     end
  end
end
