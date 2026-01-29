require 'json'

RSpec.describe 'Impact Metrics' do
  before do
    WebMock.stub_request(:post, "http://test-url/client/metrics")
      .to_return(status: 202, body: "", headers: {})

    Unleash.configure do |config|
      config.url = 'http://test-url/'
      config.app_name = 'my-test-app'
      config.environment = 'production'
      config.instance_id = 'rspec/test'
      config.disable_client = true
    end
  end

  after do
    WebMock.reset!
    File.delete(Unleash.configuration.backup_file) if File.exist?(Unleash.configuration.backup_file)
  end

  it "sends counter, gauge, and histogram metrics in payload" do
    unleash_client = Unleash::Client.new
    Unleash.reporter = Unleash::MetricsReporter.new

    unleash_client.impact_metrics.define_counter('purchases', 'Number of purchases')
    unleash_client.impact_metrics.increment_counter('purchases', 1)

    unleash_client.impact_metrics.define_gauge('temperature', 'Current temperature')
    unleash_client.impact_metrics.update_gauge('temperature', 23.5)

    unleash_client.impact_metrics.define_histogram('latency', 'Request latency', [0.1, 0.5, 1.0])
    unleash_client.impact_metrics.observe_histogram('latency', 0.3)

    Unleash.reporter.post

    expected_labels = { 'appName' => 'my-test-app', 'environment' => 'production' }

    expect(WebMock).to(have_requested(:post, 'http://test-url/client/metrics')
      .with do |req|
        body = JSON.parse(req.body)
        metrics = body['impactMetrics'].to_h { |m| [m['name'], m] }
        metrics == {
          'purchases' => {
            'name' => 'purchases',
            'help' => 'Number of purchases',
            'type' => 'counter',
            'samples' => [{ 'labels' => expected_labels, 'value' => 1 }]
          },
          'temperature' => {
            'name' => 'temperature',
            'help' => 'Current temperature',
            'type' => 'gauge',
            'samples' => [{ 'labels' => expected_labels, 'value' => 23.5 }]
          },
          'latency' => {
            'name' => 'latency',
            'help' => 'Request latency',
            'type' => 'histogram',
            'samples' => [
              {
                'labels' => expected_labels,
                'count' => 1,
                'sum' => 0.3,
                'buckets' => [
                  { 'le' => 0.1, 'count' => 0 },
                  { 'le' => 0.5, 'count' => 1 },
                  { 'le' => 1.0, 'count' => 1 },
                  { 'le' => '+Inf', 'count' => 1 }
                ]
              }
            ]
          }
        }
      end)
  end

  it "resends metrics after failure" do
    WebMock.reset!
    WebMock.stub_request(:post, "http://test-url/client/metrics")
      .to_return(status: 500, body: "", headers: {})
      .then.to_return(status: 202, body: "", headers: {})

    unleash_client = Unleash::Client.new
    Unleash.reporter = Unleash::MetricsReporter.new

    unleash_client.impact_metrics.define_counter('my_counter', 'Test counter')
    unleash_client.impact_metrics.increment_counter('my_counter', 5)

    Unleash.reporter.post
    Unleash.reporter.post

    expect(WebMock).to have_requested(:post, 'http://test-url/client/metrics')
      .with { |req|
        body = JSON.parse(req.body)
        impact_metrics = body['impactMetrics']
        impact_metrics && impact_metrics[0]['name'] == 'my_counter'
      }.times(2)
  end
end
