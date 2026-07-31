module Happn
  module IntegrationSpecProjectors
    class Recording < Happn::Projector

      class << self
        attr_accessor :matcher
      end

      def self.instances
        @instances ||= []
      end

      def self.reset!
        @instances = []
        @matcher   = { emitter: :all, kind: :all, name: :all, status: :all }
      end

      def initialize(logger, subscription_repository)
        super
        @consumed = []
        self.class.instances.push(self)
      end

      attr_reader :consumed

      def define_handlers
        on(**self.class.matcher) { |event| @consumed.push(event) }
      end
    end
  end
end
