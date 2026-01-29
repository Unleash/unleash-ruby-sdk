require "rspec/json_expectations"

RSpec.describe Unleash::MetricsReporter do
  let(:metrics_reporter) { Unleash::MetricsReporter.new }

  before do
    Unleash.configuration = Unleash::Configuration.new
    Unleash.logger = Unleash.configuration.logger
    Unleash.logger.level = Unleash.configuration.log_level
    # Unleash.logger.level = Logger::DEBUG

    Unleash.configuration.url         = 'http://test-url/'
    Unleash.configuration.app_name    = 'my-test-app'
    Unleash.configuration.instance_id = 'rspec/test'

    # Do not test the scheduled calls from client/metrics:
    Unleash.configuration.disable_client = true
    Unleash.configuration.disable_metrics = true
    metrics_reporter.last_time = Time.now
  end

  it "generates the correct report" do
    Unleash.configure do |config|
      config.url      = 'http://test-url/'
      config.app_name = 'my-test-app'
      config.instance_id = 'rspec/test'
      config.disable_client = true
    end
    Unleash.engine = YggdrasilEngine.new

    Unleash.engine.count_toggle('featureA', true)
    Unleash.engine.count_toggle('featureA', true)
    Unleash.engine.count_toggle('featureA', true)
    Unleash.engine.count_toggle('featureA', false)
    Unleash.engine.count_toggle('featureA', false)
    Unleash.engine.count_toggle('featureB', true)

    report = metrics_reporter.generate_report
    expect(report[:bucket][:toggles]).to include(
      featureA: {
        no: 2,
        yes: 3,
        variants: {}
      },
      featureB: {
        no: 0,
        yes: 1,
        variants: {}
      }
    )

    expect(report[:bucket][:toggles].to_json).to include_json(
      featureA: {
        no: 2,
        yes: 3
      },
      featureB: {
        no: 0,
        yes: 1
      }
    )
  end

  it "sends the correct report" do
    WebMock.stub_request(:post, "http://test-url/client/metrics")
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type' => 'application/json',
          'Unleash-Appname' => 'my-test-app',
          'Unleash-Instanceid' => 'rspec/test',
          'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
          'Unleash-Sdk' => "unleash-ruby-sdk:#{Unleash::VERSION}",
          'Unleash-Interval' => "60"
        }
      )
      .to_return(status: 200, body: "", headers: {})

    Unleash.engine = YggdrasilEngine.new

    Unleash.engine.count_toggle('featureA', true)
    Unleash.engine.count_toggle('featureA', true)
    Unleash.engine.count_toggle('featureA', true)
    Unleash.engine.count_toggle('featureA', false)
    Unleash.engine.count_toggle('featureA', false)
    Unleash.engine.count_toggle('featureB', true)

    metrics_reporter.post

    expect(WebMock).to have_requested(:post, 'http://test-url/client/metrics')
      .with { |req|
        hash = JSON.parse(req.body)

        [
          DateTime.parse(hash['bucket']['stop']) >= DateTime.parse(hash['bucket']['start']),
          hash['bucket']['toggles']['featureA']['yes'] == 3,
          hash['bucket']['toggles']['featureA']['no'] == 2,
          hash['bucket']['toggles']['featureB']['yes'] == 1
        ].all?(true)
      }
      .with(
        body: hash_including(
          appName: "my-test-app",
          instanceId: "rspec/test"
        )
      )
  end

  it "does not send a report, if there were no metrics registered/evaluated" do
    Unleash.engine = YggdrasilEngine.new

    metrics_reporter.post

    expect(WebMock).to_not have_requested(:post, 'http://test-url/client/metrics')
  end

  it "generates an empty report when no metrics after 10 minutes" do
    WebMock.stub_request(:post, "http://test-url/client/metrics")
      .to_return(status: 200, body: "", headers: {})
    Unleash.configure do |config|
      config.url      = 'http://test-url/'
      config.app_name = 'my-test-app'
      config.instance_id = 'rspec/test'
      config.disable_client = true
    end
    Unleash.engine = YggdrasilEngine.new

    metrics_reporter.last_time = Time.now - 601
    metrics_reporter.generate_report

    metrics_reporter.post

    expect(WebMock).to(have_requested(:post, 'http://test-url/client/metrics')
      .with do |req|
        body = JSON.parse(req.body, symbolize_names: true)

        expect(body).to include(
          platformName: anything,
          platformVersion: anything,
          yggdrasilVersion: anything,
          specVersion: anything,
          bucket: include(
            start: anything,
            stop: anything,
            toggles: {}
          )
        )

        true # tell WebMock we're done matching
      end)
  end

  it "includes metadata in the report" do
    WebMock.stub_request(:post, "http://test-url/client/metrics")
      .to_return(status: 200, body: "", headers: {})

    Unleash.engine = YggdrasilEngine.new
    Unleash.engine.count_toggle('featureA', true)

    metrics_reporter.post

    expect(WebMock).to have_requested(:post, 'http://test-url/client/metrics')
      .with(
        body: hash_including(
          yggdrasilVersion: anything,
          specVersion: anything,
          platformName: anything,
          platformVersion: anything,
          connectionId: anything
        )
      )
  end
end
