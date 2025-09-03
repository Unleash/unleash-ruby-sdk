require 'unleash/configuration'

module Unleash
  class BackupFileReader
    def self.read!
      Unleash.logger.debug "read!()"

      backup_file = Unleash.configuration.backup_file
      return nil unless File.exist?(backup_file)

      File.read(backup_file)
    rescue IOError => e
      # :nocov:
      Unleash.logger.error "Unable to read the backup_file: #{e}"
      # :nocov:
      nil
    rescue StandardError => e
      # :nocov:
      Unleash.logger.error "Unable to extract valid data from backup_file. Exception thrown: #{e}"
      # :nocov:
      nil
    end
  end
end
