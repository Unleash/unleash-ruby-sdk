require 'unleash/streaming_event_processor'
require 'unleash/bootstrap/handler'
require 'unleash/backup_file_reader'
require 'unleash/util/event_source_wrapper'

module Unleash
  class StreamingClientExecutor
    attr_accessor :name, :event_source, :event_processor, :running

    def initialize(name, engine)
      self.name = name || 'StreamingClientExecutor'
      self.event_source = nil
      self.event_processor = Unleash::StreamingEventProcessor.new(engine)
      self.running = false

      begin
        # if bootstrap configuration is available, initialize. Otherwise read backup file
        if Unleash.configuration.use_bootstrap?
          bootstrap(engine)
        else
          read_backup_file!(engine)
        end
      rescue StandardError => e
        # fall back to reading the backup file
        Unleash.logger.warn "StreamingClientExecutor was unable to initialize, attempting to read from backup file."
        Unleash.logger.debug "Exception Caught: #{e}"
        read_backup_file!(engine)
      end
    end

    def run(&_block)
      start
    end

    def start
      return if self.running || Unleash.configuration.disable_client

      Unleash.logger.debug "Streaming client #{self.name} starting connection to: #{Unleash.configuration.fetch_toggles_uri}"

      self.event_source = create_event_source
      setup_event_handlers

      self.running = true
      Unleash.logger.debug "Streaming client #{self.name} connection established"
    end

    def stop
      return unless self.running

      Unleash.logger.debug "Streaming client #{self.name} stopping connection"
      self.running = false
      self.event_source&.close
      self.event_source = nil
      Unleash.logger.debug "Streaming client #{self.name} connection closed"
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
        Unleash.logger.warn "Streaming client #{self.name} error: #{error}"
      end
    end

    def handle_event(event)
      self.event_processor.process_event(event)
    rescue StandardError => e
      Unleash.logger.error "Streaming client #{self.name} threw exception #{e.class}: '#{e}'"
      Unleash.logger.debug "stacktrace: #{e.backtrace}"
    end

    def read_backup_file!(engine)
      backup_data = Unleash::BackupFileReader.read!
      engine.take_state(backup_data) if backup_data
    end

    def bootstrap(engine)
      bootstrap_payload = Unleash::Bootstrap::Handler.new(Unleash.configuration.bootstrap_config).retrieve_toggles
      engine.take_state(bootstrap_payload)

      # reset Unleash.configuration.bootstrap_data to free up memory, as we will never use it again
      Unleash.configuration.bootstrap_config = nil
    end
  end
end
