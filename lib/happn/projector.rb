module Happn
  class Projector
    @@event_handlers_by_name       = {}
    @@event_handlers_by_expression = {}

    def initialize
      @logger = Happn.logger
    end

    def handled_event_names
      @@event_handlers_by_name.keys
    end

    def handled_event_expressions
      @@event_handlers_by_expression.keys
    end

    def self.on(event_expression, &block)
      if event_expression.instance_of? Regexp
        @@event_handlers_by_expression[event_expression] = block
      else
        @@event_handlers_by_name[event_expression] = block
      end
    end

    def handle_by_expression(event, data)
      meta       = event.fetch("meta")
      event_name = meta.fetch("name")
      @@event_handlers_by_expression.each do | event_expression, handler|
        instance_exec(event, data, &handler) if event_name.match(event_expression)
      end
      @logger.debug("Handle #{event_name} from #{meta.fetch("emitter")}: #{data}")
    end

    def handle_by_name(event, data)
      meta       = event.fetch("meta")
      event_name = meta.fetch("name")
      handler    = @@event_handlers_by_name[event_name]
      unless handler.nil?
        instance_exec(event, data, &handler)
        @logger.debug("Handle #{event_name} from #{meta.fetch("emitter")}: #{data}")
      end
    end
  end
end
