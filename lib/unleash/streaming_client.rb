require 'ld-eventsource'
require 'json'

module Unleash
  class StreamingClient
    attr_accessor :event_source, :toggle_engine, :running, :mutex

    def initialize(toggle_engine)
      self.toggle_engine = toggle_engine
      self.event_source = nil
      self.running = false
      self.mutex = Mutex.new
    end

    def start
      self.mutex.synchronize do
        return if self.running || Unleash.configuration.disable_client

        Unleash.logger.debug "Starting streaming from URL: #{Unleash.configuration.fetch_toggles_uri}"

        headers = (Unleash.configuration.http_headers || {}).dup

        self.event_source = SSE::Client.new(
          Unleash.configuration.fetch_toggles_uri.to_s,
          headers: headers,
          read_timeout: 60, # start a new SSE connection when no heartbeat received in 1 minute
          reconnect_time: 2,
          connect_timeout: 10,
          logger: Unleash.logger
        )

        self.event_source.on_event do |event|
          handle_event(event)
        end

        self.event_source.on_error do |error|
          Unleash.logger.warn "Streaming error: #{error}"
        end

        self.running = true
      end
    end

    def stop
      self.mutex.synchronize do
        return unless self.running

        Unleash.logger.info "Stopping streaming client"
        self.running = false
        self.event_source&.close
        self.event_source = nil
      end
    end

    def running?
      self.mutex.synchronize{ self.running }
    end

    private

    def handle_event(event)
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

    def handle_connected_event(event)
      Unleash.logger.debug "Processing initial hydration data"
      handle_updated_event(event)
    end

    def handle_updated_event(event)
      self.mutex.synchronize do
        self.toggle_engine.take_state(event.data)
      end

      # TODO: update backup file
    rescue JSON::ParserError => e
      Unleash.logger.error "Failed to parse streaming event data: #{e.message}"
    rescue StandardError => e
      Unleash.logger.error "Error processing delta update: #{e.message}"
    end
  end
end
