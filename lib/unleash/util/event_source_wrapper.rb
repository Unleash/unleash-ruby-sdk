module Unleash
  module Util
    module EventSourceWrapper
      def self.client
        return nil if RUBY_ENGINE == 'jruby'

        begin
          require 'ld-eventsource'
          SSE::Client
        rescue LoadError => e
          Unleash.logger.error "Failed to load ld-eventsource: #{e.message}"
          nil
        end
      end
    end
  end
end
