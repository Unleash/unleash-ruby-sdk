require 'json'

module Unleash
  class StreamingEventProcessor
    attr_accessor :toggle_engine, :mutex

    def initialize(toggle_engine)
      self.toggle_engine = toggle_engine
      self.mutex = Mutex.new
    end

    def process_event(event)
      case event.type.to_s
      when 'unleash-connected'
        Unleash.logger.debug "Streaming client connected"
        handle_connected_event(event)
      when 'unleash-updated'
        Unleash.logger.debug "Received streaming update"
        handle_updated_event(event)
      else
        Unleash.logger.debug "Received unknown event type: #{event.type}"
      end
    rescue StandardError => e
      Unleash.logger.error "Error handling streaming event: #{e.message}"
    end

    def handle_delta_event(event_data)
      self.mutex.synchronize do
        self.toggle_engine.take_state(event_data)
      end
    end

    private

    def handle_connected_event(event)
      Unleash.logger.debug "Processing initial hydration data"
      handle_updated_event(event)
    end

    def handle_updated_event(event)
      handle_delta_event(event.data)

      # TODO: update backup file
    rescue JSON::ParserError => e
      Unleash.logger.error "Failed to parse streaming event data: #{e.message}"
    rescue StandardError => e
      Unleash.logger.error "Error processing delta update: #{e.message}"
    end
  end
end
