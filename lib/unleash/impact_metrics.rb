module Unleash
  class MetricFlagContext
    attr_accessor :flag_names, :context

    def initialize(flag_names: [], context: nil)
      @flag_names = flag_names
      @context = context
    end
  end

  class ImpactMetrics
    def initialize(engine, app_name, environment)
      @engine = engine
      @base_labels = {
        'appName' => app_name,
        'environment' => environment
      }
    end

    def define_counter(name, help_text)
      @engine.define_counter(name, help_text)
    end

    def increment_counter(name, value = 1, flag_context = nil)
      labels = resolve_labels(flag_context)
      @engine.inc_counter(name, value, labels)
    end

    def define_gauge(name, help_text)
      @engine.define_gauge(name, help_text)
    end

    def update_gauge(name, value, flag_context = nil)
      labels = resolve_labels(flag_context)
      @engine.set_gauge(name, value, labels)
    end

    def define_histogram(name, help_text, buckets = nil)
      @engine.define_histogram(name, help_text, buckets)
    end

    def observe_histogram(name, value, flag_context = nil)
      labels = resolve_labels(flag_context)
      @engine.observe_histogram(name, value, labels)
    end

    private

    def resolve_labels(flag_context)
      return @base_labels.dup unless flag_context

      flag_labels = flag_context.flag_names.to_h do |flag_name|
        [flag_name, variant_label(flag_name, flag_context.context)]
      end
      @base_labels.merge(flag_labels)
    end

    def variant_label(flag_name, context)
      variant = @engine.get_variant(flag_name, context || {})

      return variant[:name] if variant && variant[:enabled]
      return 'enabled' if variant && variant[:feature_enabled]

      'disabled'
    end
  end
end
