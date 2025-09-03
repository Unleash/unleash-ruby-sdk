require 'unleash/configuration'
require 'unleash/bootstrap/handler'
require 'unleash/backup_file_writer'
require 'unleash/backup_file_reader'
require 'net/http'
require 'json'
require 'yggdrasil_engine'

module Unleash
  class ToggleFetcher
    attr_accessor :toggle_engine, :toggle_lock, :toggle_resource, :etag, :retry_count

    def initialize(engine)
      self.toggle_engine = engine
      self.etag = nil
      self.toggle_lock = Mutex.new
      self.toggle_resource = ConditionVariable.new
      self.retry_count = 0

      begin
        # if bootstrap configuration is available, initialize. An immediate API read is also triggered
        if Unleash.configuration.use_bootstrap?
          bootstrap
        else
          fetch
        end
      rescue StandardError => e
        # fall back to reading the backup file
        Unleash.logger.warn "ToggleFetcher was unable to fetch from the network, attempting to read from backup file."
        Unleash.logger.debug "Exception Caught: #{e}"
        read_backup_file!
      end

      # once initialized, somewhere else you will want to start a loop with fetch()
    end

    # rename to refresh_from_server!  ??
    def fetch
      Unleash.logger.debug "fetch()"
      return if Unleash.configuration.disable_client

      headers = (Unleash.configuration.http_headers || {}).dup
      headers.merge!({ 'UNLEASH-INTERVAL' => Unleash.configuration.refresh_interval.to_s })
      response = Unleash::Util::Http.get(Unleash.configuration.fetch_toggles_uri, etag, headers)

      if response.code == '304'
        Unleash.logger.debug "No changes according to the unleash server, nothing to do."
        return
      elsif response.code != '200'
        raise IOError, "Unleash server returned unexpected HTTP response code #{response.code}."\
          " Only handle response codes 200 (indicates changes) or 304 (no changes)."
      end

      self.etag = response['ETag']

      # always synchronize with the local cache when fetching:
      update_engine_state!(response.body)

      Unleash::BackupFileWriter.save! response.body
    end

    private

    def update_engine_state!(toggle_data)
      self.toggle_lock.synchronize do
        self.toggle_engine.take_state(toggle_data)
      end

      # notify all threads waiting for this resource to no longer wait
      self.toggle_resource.broadcast
    rescue StandardError => e
      Unleash.logger.error "Failed to hydrate state: #{e.backtrace}"
    end

    def read_backup_file!
      backup_data = Unleash::BackupFileReader.read!
      update_engine_state!(backup_data) if backup_data
    end

    def bootstrap
      bootstrap_payload = Unleash::Bootstrap::Handler.new(Unleash.configuration.bootstrap_config).retrieve_toggles
      update_engine_state! bootstrap_payload

      # reset Unleash.configuration.bootstrap_data to free up memory, as we will never use it again
      Unleash.configuration.bootstrap_config = nil
    end
  end
end
