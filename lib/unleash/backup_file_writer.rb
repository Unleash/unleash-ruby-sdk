require 'unleash/configuration'

module Unleash
  class BackupFileWriter
    def self.save!(toggle_data)
      Unleash.logger.debug "Will save toggles to disk now"

      backup_file = Unleash.configuration.backup_file
      backup_file_tmp = "#{backup_file}.tmp-#{Process.pid}"

      File.open(backup_file_tmp, "w") do |file|
        file.write(toggle_data)
      end
      File.rename(backup_file_tmp, backup_file)
    rescue StandardError => e
      # This is not really the end of the world. Swallowing the exception.
      Unleash.logger.error "Unable to save backup file. Exception thrown #{e.class}:'#{e}'"
      Unleash.logger.error "stacktrace: #{e.backtrace}"
    end
  end
end
