require 'unleash/configuration'
require 'net/http'
require 'json'
require 'time'

module Unleash
  class MetricsReporter
    LONGEST_WITHOUT_A_REPORT = 600

    attr_accessor :last_time

    def initialize
      self.last_time = Time.now
    end

    def generate_report
      metrics = Unleash.engine&.get_metrics
      return nil if metrics.nil?

      generate_report_from_bucket metrics
    end

    def post
      Unleash.logger.debug "post() Report"

      impact_metrics = collect_impact_metrics_safely
      report = build_report(impact_metrics)
      return unless report

      send_report(report)
    end

    private

    def generate_report_from_bucket(bucket)
      {
        'platformName': RUBY_ENGINE,
        'platformVersion': RUBY_VERSION,
        'yggdrasilVersion': "0.13.3",
        'specVersion': Unleash::CLIENT_SPECIFICATION_VERSION,
        'appName': Unleash.configuration.app_name,
        'instanceId': Unleash.configuration.instance_id,
        'connectionId': Unleash.configuration.connection_id,
        'bucket': bucket
      }
    end

    def build_report(impact_metrics)
      report = generate_report
      has_data = !report.nil? || !impact_metrics.empty?

      return nil if !has_data && Time.now - self.last_time < LONGEST_WITHOUT_A_REPORT

      report ||= generate_report_from_bucket({
        'start': self.last_time.utc.iso8601,
        'stop': Time.now.utc.iso8601,
        'toggles': {}
      })

      report[:impactMetrics] = impact_metrics unless impact_metrics.empty?
      report
    end

    def send_report(report)
      self.last_time = Time.now
      headers = (Unleash.configuration.http_headers || {}).dup
      headers.merge!({ 'UNLEASH-INTERVAL' => Unleash.configuration.metrics_interval.to_s })
      response = Unleash::Util::Http.post(Unleash.configuration.client_metrics_uri, report.to_json, headers)

      if ['200', '202'].include? response.code
        Unleash.logger.debug "Report sent to unleash server successfully. Server responded with http code #{response.code}"
      else
        # :nocov:
        Unleash.logger.error "Error when sending report to unleash server. Server responded with http code #{response.code}."
        restore_impact_metrics(report[:impactMetrics])
        # :nocov:
      end
    end

    def restore_impact_metrics(impact_metrics)
      return if impact_metrics.nil? || impact_metrics.empty?

      Unleash.engine&.restore_impact_metrics(impact_metrics)
    rescue StandardError => e
      Unleash.logger.warn "Failed to restore impact metrics: #{e.message}"
    end

    def collect_impact_metrics_safely
      Unleash.engine&.collect_impact_metrics || []
    rescue StandardError => e
      Unleash.logger.warn "Failed to collect impact metrics: #{e.message}"
      []
    end
  end
end
