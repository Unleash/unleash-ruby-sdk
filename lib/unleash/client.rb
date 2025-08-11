require 'unleash/configuration'
require 'unleash/toggle_fetcher'
require 'unleash/metrics_reporter'
require 'unleash/scheduled_executor'
require 'unleash/streaming_client_executor'
require 'unleash/variant'
require 'unleash/util/http'
require 'unleash/util/event_source_wrapper'
require 'logger'
require 'time'

module Unleash
  class Client
    attr_accessor :fetcher_scheduled_executor, :metrics_scheduled_executor

    # rubocop:disable Metrics/AbcSize
    def initialize(*opts)
      Unleash.configuration = Unleash::Configuration.new(*opts) unless opts.empty?
      Unleash.configuration.validate!

      Unleash.logger = Unleash.configuration.logger.clone
      Unleash.logger.level = Unleash.configuration.log_level
      Unleash.engine = YggdrasilEngine.new
      Unleash.engine.register_custom_strategies(Unleash.configuration.strategies.custom_strategies)

      Unleash.toggle_fetcher = Unleash::ToggleFetcher.new Unleash.engine unless Unleash.configuration.streaming_mode?

      if Unleash.configuration.disable_client
        Unleash.logger.warn "Unleash::Client is disabled! Will only return default (or bootstrapped if available) results!"
        Unleash.logger.warn "Unleash::Client is disabled! Metrics and MetricsReporter are also disabled!"
        Unleash.configuration.disable_metrics = true
        return
      end

      register

      initialize_client_mode

      start_metrics unless Unleash.configuration.disable_metrics
    end
    # rubocop:enable Metrics/AbcSize

    def is_enabled?(feature, context = nil, default_value_param = false, &fallback_blk)
      Unleash.logger.debug "Unleash::Client.is_enabled? feature: #{feature} with context #{context}"

      default_value = if block_given?
                        default_value_param || !!fallback_blk.call(feature, context)
                      else
                        default_value_param
                      end

      toggle_enabled = Unleash.engine.enabled?(feature, context)
      if toggle_enabled.nil?
        Unleash.logger.debug "Unleash::Client.is_enabled? feature: #{feature} not found"
        Unleash.engine.count_toggle(feature, false)
        return default_value
      end

      Unleash.engine.count_toggle(feature, toggle_enabled)

      toggle_enabled
    end

    def is_disabled?(feature, context = nil, default_value_param = true, &fallback_blk)
      !is_enabled?(feature, context, !default_value_param, &fallback_blk)
    end

    # enabled? is a more ruby idiomatic method name than is_enabled?
    alias enabled? is_enabled?
    # disabled? is a more ruby idiomatic method name than is_disabled?
    alias disabled? is_disabled?

    # execute a code block (passed as a parameter), if is_enabled? is true.
    def if_enabled(feature, context = nil, default_value = false, &blk)
      yield(blk) if is_enabled?(feature, context, default_value)
    end

    # execute a code block (passed as a parameter), if is_disabled? is true.
    def if_disabled(feature, context = nil, default_value = true, &blk)
      yield(blk) if is_disabled?(feature, context, default_value)
    end

    def get_variant(feature, context = Unleash::Context.new, fallback_variant = disabled_variant)
      variant = Unleash.engine.get_variant(feature, context)

      if variant.nil?
        Unleash.logger.debug "Unleash::Client.get_variant variants for feature: #{feature} not found"
        Unleash.engine.count_toggle(feature, false)
        return fallback_variant
      end

      variant = Variant.new(variant)

      Unleash.engine.count_variant(feature, variant.name)
      Unleash.engine.count_toggle(feature, variant.feature_enabled)

      # TODO: Add to README: name, payload, enabled (bool)

      variant
    end

    # safe shutdown: also flush metrics to server and toggles to disk
    def shutdown
      unless Unleash.configuration.disable_client
        Unleash.reporter.post unless Unleash.configuration.disable_metrics
        shutdown!
      end
    end

    # quick shutdown: just kill running threads
    def shutdown!
      unless Unleash.configuration.disable_client
        self.fetcher_scheduled_executor&.exit
        self.metrics_scheduled_executor.exit unless Unleash.configuration.disable_metrics
      end
    end

    private

    def info
      {
        'appName': Unleash.configuration.app_name,
        'instanceId': Unleash.configuration.instance_id,
        'connectionId': Unleash.configuration.connection_id,
        'sdkVersion': "unleash-client-ruby:" + Unleash::VERSION,
        'strategies': Unleash.strategies.known_strategies,
        'started': Time.now.iso8601(Unleash::TIME_RESOLUTION),
        'interval': Unleash.configuration.metrics_interval_in_millis,
        'platformName': RUBY_ENGINE,
        'platformVersion': RUBY_VERSION,
        'yggdrasilVersion': "0.13.3",
        'specVersion': Unleash::CLIENT_SPECIFICATION_VERSION
      }
    end

    def start_toggle_fetcher
      self.fetcher_scheduled_executor = Unleash::ScheduledExecutor.new(
        'ToggleFetcher',
        Unleash.configuration.refresh_interval,
        Unleash.configuration.retry_limit,
        first_fetch_is_eager
      )
      self.fetcher_scheduled_executor.run do
        Unleash.toggle_fetcher.fetch
      end
    end

    def start_streaming_client
      self.fetcher_scheduled_executor = Unleash::StreamingClientExecutor.new('StreamingExecutor', Unleash.engine)
      self.fetcher_scheduled_executor.run
    end

    def start_metrics
      Unleash.reporter = Unleash::MetricsReporter.new
      self.metrics_scheduled_executor = Unleash::ScheduledExecutor.new(
        'MetricsReporter',
        Unleash.configuration.metrics_interval,
        Unleash.configuration.retry_limit
      )
      self.metrics_scheduled_executor.run do
        Unleash.reporter.post
      end
    end

    def register
      Unleash.logger.debug "register()"

      # Send the request, if possible
      begin
        response = Unleash::Util::Http.post(Unleash.configuration.client_register_uri, info.to_json)
      rescue StandardError => e
        Unleash.logger.error "unable to register client with unleash server due to exception #{e.class}:'#{e}'."
        Unleash.logger.error "stacktrace: #{e.backtrace}"
      end
      Unleash.logger.debug "client registered: #{response}"
    end

    def disabled_variant
      @disabled_variant ||= Unleash::Variant.disabled_variant
    end

    def first_fetch_is_eager
      Unleash.configuration.use_bootstrap?
    end

    def initialize_client_mode
      if Unleash.configuration.streaming_mode?
        start_streaming_client
      else
        start_toggle_fetcher
      end
    end
  end
end
