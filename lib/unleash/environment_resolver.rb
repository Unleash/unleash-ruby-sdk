module Unleash
  class EnvironmentResolver
    def self.extract_environment_from_custom_headers(custom_headers)
      authorization_header = extract_authorization_header(custom_headers)
      extract_environment_from_header(authorization_header)
    end

    def self.extract_authorization_header(custom_headers)
      return nil if custom_headers.nil? || !custom_headers.is_a?(Hash)

      key = custom_headers.keys.find{ |k| k.to_s.downcase == 'authorization' }
      custom_headers[key] if key
    end

    def self.extract_environment_from_header(authorization_header)
      return nil if authorization_header.nil? || authorization_header.empty?

      after_colon = authorization_header.split(':', 2)[1]
      return nil unless after_colon&.include?('.')

      environment = after_colon.split('.')[0]
      environment unless environment.empty?
    end

    private_class_method :extract_authorization_header, :extract_environment_from_header
  end
end
