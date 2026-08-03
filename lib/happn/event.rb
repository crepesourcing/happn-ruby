require "date"

module Happn
  # A single CREPE event, as it was consumed from the exchange.
  #
  # An event is built from the parsed payload of a message. That payload carries
  # two entries: `meta`, describing the event itself, and `data`, describing what
  # happened. A projector handler receives an instance of this class.
  #
  # ## Key conversion
  #
  # Every key of the payload, at every depth, is converted into an underscored
  # Symbol when the event is built. A payload emitted in camel case is therefore
  # read in snake case, and always through symbols:
  #
  #     # {"meta" => {…}, "data" => {"requestMetadata" => {"controllerName" => "countries"}}}
  #     event.data[:request_metadata][:controller_name]  # => "countries"
  #     event.data["request_metadata"]                   # => nil
  #
  # Dashes become underscores, `::` becomes `/`, and the capitals of an acronym
  # are kept together: `"HTTPResponseCode"` is read as `:http_response_code`.
  #
  # ## Changes
  #
  # An entity change carries a `changes` entry, mapping an attribute to the pair
  # of values it went through:
  #
  #     event.changes  # => { name: ["France", "Belgium"] }
  #
  # Events of another shape carry no such entry at all, a `request` for instance.
  # {#changes} then returns `nil`, and the five methods reading through it raise
  # a NoMethodError: guard them with {#changes} when a handler may be reached by
  # events of several shapes.
  #
  # @example Reading an event in a projector
  #   on kind: "entity_change", name: "update country" do |event|
  #     Rails.logger.info("#{event.emitter} renamed a country at #{event.timestamp}")
  #     Rails.logger.info("from #{event.change_before(:name)} to #{event.change_after(:name)}")
  #   end
  class Event

    # The whole `data` entry of the payload, keys converted.
    #
    # This is the hash the event holds, not a copy: {#changes=} and {#add_change}
    # write into it, and so does anything the caller does to it.
    #
    # @return [Hash] the payload data, or whatever `data` held if it was no hash
    attr_reader :data

    # Builds an event from a parsed payload.
    #
    # @param args [Hash] the parsed payload, with its `"meta"` and `"data"`
    #   entries, both keyed by String
    # @raise [KeyError] if the payload carries no `"meta"` or no `"data"` entry
    def initialize(args)
      @meta = deep_underscore_keys(args.fetch("meta"))
      @data = deep_underscore_keys(args.fetch("data"))
    end

    # The metadata the emitter attached to the user behind the event.
    #
    # @return [Hash, nil] nil when the payload carries no `user_metadata`
    def user_metadata
      @data[:user_metadata]
    end

    # The metadata the emitter attached to the request behind the event.
    #
    # @return [Hash, nil] nil when the payload carries no `request_metadata`
    def request_metadata
      @data[:request_metadata]
    end

    # The attributes the event changed, each mapped to its before and after
    # values.
    #
    # @return [Hash{Symbol => Array}, nil] nil when the payload carries no
    #   `changes` entry, which is the case of every event that is not an entity
    #   change
    def changes
      @data[:changes]
    end

    # Replaces the whole set of changes.
    #
    # Keys are taken as they are given: unlike the ones read from the payload,
    # they go through no conversion.
    #
    # @param new_changes [Hash{Symbol => Array}] the changes to substitute
    # @return [Hash{Symbol => Array}] the changes that were set
    def changes=(new_changes)
      @data[:changes] = new_changes
    end

    # Records a change on an attribute.
    #
    # The "before" value is always `nil`: the method describes a value that was
    # set, not a transition. An empty String is normalized into `nil`, so that a
    # blank emitted value and an absent one are recorded alike.
    #
    # @example
    #   event.add_change(:name, "Belgium")  # => [nil, "Belgium"]
    #   event.add_change(:name, "")         # => [nil, nil]
    #
    # @param name [Symbol, String] the attribute the change bears on
    # @param value [Object] the value the attribute was set to
    # @return [Array] the pair of values recorded
    # @raise [NoMethodError] if the payload carries no `changes` entry
    def add_change(name, value)
      new_value            = value == "" ? nil : value
      changes[name.to_sym] = [nil, new_value]
    end

    # The entities the event relates to.
    #
    # @return [Hash, nil] nil when the payload carries no `associations`
    def associations
      @data[:associations]
    end

    # When the event was emitted.
    #
    # The raw value is parsed on every call, and its offset is kept as it was
    # emitted rather than being normalized.
    #
    # @return [DateTime, nil] nil when the payload carries no timestamp, or an
    #   empty one
    # @raise [Date::Error] if the timestamp cannot be parsed
    def timestamp
      raw_timestamp = @meta[:timestamp]
      if raw_timestamp.nil? || raw_timestamp.to_s.strip.empty?
        nil
      else
        DateTime.parse(raw_timestamp)
      end
    end

    # The identifier the emitter gave the event.
    #
    # @return [String, nil] nil when the payload carries no id
    def id
      @meta[:id]
    end

    # What the event says happened, matched by the `name` of a query.
    #
    # @return [String, nil] nil when the payload carries no name
    def name
      @meta[:name]
    end

    # The state of the event, matched by the `status` of a query.
    #
    # @return [String, nil] nil when the payload carries no status
    def status
      @meta[:status]
    end

    # The category of the event, matched by the `kind` of a query.
    #
    # @return [String, nil] nil when the payload carries no kind
    def kind
      @meta[:kind]
    end

    # The application the event comes from, matched by the `emitter` of a query.
    #
    # @return [String, nil] nil when the payload carries no emitter
    def emitter
      @meta[:emitter]
    end

    # The value an attribute was changed to.
    #
    # @param attribute_name [Symbol, String] the attribute to read
    # @return [Object, nil] nil when the attribute did not change
    # @raise [NoMethodError] if the payload carries no `changes` entry
    def change_after(attribute_name)
      changes[attribute_name.to_sym]&.last
    end

    # The value an attribute was changed from.
    #
    # @param attribute_name [Symbol, String] the attribute to read
    # @return [Object, nil] nil when the attribute did not change
    # @raise [NoMethodError] if the payload carries no `changes` entry
    def change_before(attribute_name)
      changes[attribute_name.to_sym]&.first
    end

    # Whether an attribute changed.
    #
    # @param attribute_name [Symbol, String] the attribute to look for
    # @return [Boolean]
    # @raise [NoMethodError] if the payload carries no `changes` entry
    def has_change?(attribute_name)
      !changes[attribute_name.to_sym].nil?
    end

    # Drops the change recorded on an attribute.
    #
    # @param attribute_name [Symbol, String] the attribute to drop
    # @return [Array, nil] the pair of values that was dropped, nil when the
    #   attribute did not change
    # @raise [NoMethodError] if the payload carries no `changes` entry
    def delete_change(attribute_name)
      changes.delete(attribute_name.to_sym)
    end

    # Underscoring a key is five regular expression passes and three String
    # allocations, and an event stream keeps sending the very same keys. The cache
    # is therefore bound by the vocabulary of the payloads, which is closed: an
    # emitter putting a variable part inside a key name would make it grow forever.
    UNDERSCORED_KEYS = {}
    private_constant :UNDERSCORED_KEYS

    private

    # Converts a payload key into the symbol the event is read through, memoized
    # for every event at once.
    #
    # @param key [String] a key as the emitter wrote it
    # @return [Symbol] its underscored form
    def underscore_key(key)
      UNDERSCORED_KEYS[key] ||= underscore(key).to_sym
    end

    # Converts the keys of a payload fragment, walking through hashes and arrays
    # down to the values, which are left as they are.
    #
    # @param value [Object] a fragment of the payload
    # @return [Object] the same fragment, keyed by underscored symbols
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

    # Underscores a word, splitting it on its capitals and turning `::` into `/`.
    #
    # @param camel_cased_word [String] the word to convert
    # @return [String] its underscored, downcased form
    def underscore(camel_cased_word)
      camel_cased_word.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
     end
  end
end
