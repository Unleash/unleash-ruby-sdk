require 'unleash/streaming_event_processor'
require 'unleash/util/event_source_wrapper'

module Unleash
  class StreamingClientExecutor
    attr_accessor :name, :event_source, :event_processor, :running

    def initialize(name, engine)
      self.name = name || 'StreamingClientExecutor'
      self.event_source = nil
      self.event_processor = Unleash::StreamingEventProcessor.new(engine)
      self.running = false
    end

    def run(&_block)
      start
    end

    def start
      return if self.running || Unleash.configuration.disable_client

      Unleash.logger.debug "Starting streaming executor from URL: #{Unleash.configuration.fetch_toggles_uri}"

      self.event_source = create_event_source
      setup_event_handlers

      self.running = true
    end

    def stop
      return unless self.running

      Unleash.logger.info "Stopping streaming executor"
      self.running = false
      self.event_source&.close
      self.event_source = nil
    end

    alias exit stop

    def running?
      self.running
    end

    private

    def create_event_source
      sse_client = Unleash::Util::EventSourceWrapper.client
      if sse_client.nil?
        raise "Streaming mode is configured but EventSource client is not available. " \
              "Please install the 'ld-eventsource' gem or switch to polling mode."
      end

      headers = (Unleash.configuration.http_headers || {}).dup

      sse_client.new(
        Unleash.configuration.fetch_toggles_uri.to_s,
        headers: headers,
        read_timeout: 60,
        reconnect_time: 2,
        connect_timeout: 10,
        logger: Unleash.logger
      )
    end

    def setup_event_handlers
      self.event_source.on_event do |event|
        handle_event(event)
      end

      self.event_source.on_error do |error|
        Unleash.logger.warn "Streaming error: #{error}"
      end
    end

    def handle_event(event)
      self.event_processor.process_event(event)
    rescue StandardError => e
      Unleash.logger.error "Error in streaming executor event handling: #{e.message}"
    end
  end
end
