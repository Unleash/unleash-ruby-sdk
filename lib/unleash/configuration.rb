require 'securerandom'
require 'tmpdir'
require 'unleash/bootstrap/configuration'

module Unleash
  class Configuration
    attr_accessor \
      :url,
      :app_name,
      :environment,
      :instance_id,
      :project_name,
      :custom_http_headers,
      :disable_client,
      :disable_metrics,
      :timeout,
      :retry_limit,
      :refresh_interval,
      :metrics_interval,
      :backup_file,
      :logger,
      :log_level,
      :bootstrap_config,
      :strategies,
      :use_delta_api
    attr_reader :connection_id

    def initialize(opts = {})
      validate_custom_http_headers!(opts[:custom_http_headers]) if opts.has_key?(:custom_http_headers)
      set_defaults

      initialize_default_logger if opts[:logger].nil?

      merge(opts)
      refresh_backup_file!
    end

    def metrics_interval_in_millis
      self.metrics_interval * 1_000
    end

    def validate!
      return if self.disable_client

      raise ArgumentError, "app_name is a required parameter." if self.app_name.nil?

      validate_custom_http_headers!(self.custom_http_headers) unless self.url.nil?
    end

    def refresh_backup_file!
      self.backup_file = File.join(Dir.tmpdir, "unleash-#{app_name}-repo.json")
    end

    def http_headers
      headers = {
        'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
        'UNLEASH-INSTANCEID' => self.instance_id,
        'UNLEASH-APPNAME' => self.app_name,
        'Unleash-Client-Spec' => CLIENT_SPECIFICATION_VERSION,
        'UNLEASH-SDK' => "unleash-ruby-sdk:#{Unleash::VERSION}"
      }.merge!(generate_custom_http_headers)
      headers['UNLEASH-CONNECTION-ID'] = @connection_id
      headers
    end

    def fetch_toggles_uri
      uri = nil
      ## Personal feeling but Rubocop's suggestion here is too dense to be properly readable
      # rubocop:disable Style/ConditionalAssignment
      if self.use_delta_api
        uri = URI("#{self.url_stripped_of_slash}/client/delta")
      else
        uri = URI("#{self.url_stripped_of_slash}/client/features")
      end
      # rubocop:enable Style/ConditionalAssignment
      uri.query = "project=#{self.project_name}" unless self.project_name.nil?
      uri
    end

    def client_metrics_uri
      URI("#{self.url_stripped_of_slash}/client/metrics")
    end

    def client_register_uri
      URI("#{self.url_stripped_of_slash}/client/register")
    end

    def url_stripped_of_slash
      self.url.delete_suffix '/'
    end

    def use_bootstrap?
      self.bootstrap_config&.valid?
    end

    private

    def set_defaults
      self.app_name         = nil
      self.environment      = 'default'
      self.url              = nil
      self.instance_id      = SecureRandom.uuid
      self.project_name     = nil
      self.disable_client   = false
      self.disable_metrics  = false
      self.refresh_interval = 15
      self.metrics_interval = 60
      self.timeout          = 30
      self.retry_limit      = Float::INFINITY
      self.backup_file      = nil
      self.log_level        = Logger::WARN
      self.bootstrap_config = nil
      self.strategies       = Unleash::Strategies.new
      self.use_delta_api    = false

      self.custom_http_headers = {}
      @connection_id = SecureRandom.uuid
    end

    def initialize_default_logger
      self.logger = Logger.new($stdout)

      # on default logger, use custom formatter that includes thread_name:
      self.logger.formatter = proc do |severity, datetime, _progname, msg|
        thread_name = (Thread.current[:name] || "Unleash").rjust(16, ' ')
        "[#{datetime.iso8601(6)} #{thread_name} #{severity.ljust(5, ' ')}] : #{msg}\n"
      end
    end

    def merge(opts)
      opts.each_pair{ |opt, val| set_option(opt, val) }
      self
    end

    def validate_custom_http_headers!(custom_http_headers)
      return if custom_http_headers.is_a?(Hash) || custom_http_headers.respond_to?(:call)

      raise ArgumentError, "custom_http_headers must be a Hash or a Proc."
    end

    def generate_custom_http_headers
      return self.custom_http_headers.call if self.custom_http_headers.respond_to?(:call)

      self.custom_http_headers
    end

    def set_option(opt, val)
      __send__("#{opt}=", val)
    rescue NoMethodError
      raise ArgumentError, "unknown configuration parameter '#{val}'"
    end
  end
end
