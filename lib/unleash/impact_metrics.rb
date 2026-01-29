module Unleash
  class ImpactMetrics
    def initialize(engine, app_name)
      @engine = engine
      @app_name = app_name
    end

    def define_counter(name, help_text)
      @engine.define_counter(name, help_text)
    end

    def increment_counter(name, value = 1)
      @engine.inc_counter(name, value, base_labels)
    end

    def define_gauge(name, help_text)
      @engine.define_gauge(name, help_text)
    end

    def update_gauge(name, value)
      @engine.set_gauge(name, value, base_labels)
    end

    def define_histogram(name, help_text, buckets = nil)
      @engine.define_histogram(name, help_text, buckets)
    end

    def observe_histogram(name, value)
      @engine.observe_histogram(name, value, base_labels)
    end

    private

    def base_labels
      {
        'appName' => @app_name,
        'environment' => EnvironmentResolver.extract_environment_from_custom_headers(
          Unleash.configuration.generate_custom_http_headers
        ) || Unleash.configuration.environment
      }
    end
  end
end
