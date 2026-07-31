module Happn
  module SpecProjectors

    # Records every event it consumes, and exposes an instance method so the
    # specs can prove handlers are evaluated in the projector's own context.
    class Recording < Happn::Projector

      def self.instances
        @instances ||= []
      end

      def self.reset!
        @instances = []
      end

      def initialize(logger, subscription_repository)
        super
        @consumed = []
        self.class.instances.push(self)
      end

      attr_reader :consumed

      def define_handlers
        on(name: "create country") { |event| record(event) }
      end

      def record(event)
        @consumed.push(event)
      end
    end

    # Consumes everything, whatever the routing attributes are.
    class CatchAll < Happn::Projector
      def define_handlers
        on { |event| event }
      end
    end

    # Registers nothing: `define_handlers` is inherited as a no-op.
    class Silent < Happn::Projector
    end
  end
end
