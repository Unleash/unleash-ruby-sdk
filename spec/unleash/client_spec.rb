require "securerandom"

RSpec.describe Unleash::Client do
  after do
    WebMock.reset!
    File.delete(Unleash.configuration.backup_file) if File.exist?(Unleash.configuration.backup_file)
  end

  it "Uses custom http headers when initializing client" do
    fixed_uuid = "123e4567-e89b-12d3-a456-426614174000"
    allow(SecureRandom).to receive(:uuid).and_return(fixed_uuid)

    WebMock.stub_request(:post, "http://test-url/client/register")
      .with(
        headers: {
          'Accept' => '*/*',
          'Content-Type' => 'application/json',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
          'Unleash-Sdk' => "unleash-client-ruby:#{Unleash::VERSION}",
          'X-Api-Key' => '123'
        }
      )
      .to_return(status: 200, body: "", headers: {})
    WebMock.stub_request(:post, "http://test-url/client/metrics")
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type' => 'application/json',
          'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
          'Unleash-Sdk' => "unleash-client-ruby:#{Unleash::VERSION}",
          'Unleash-Interval' => '60'
        }
      )
      .to_return(status: 200, body: "", headers: {})

    simple_features = {
      "version": 1,
      "features": [
        {
          "name": "Feature.A",
          "description": "Enabled toggle",
          "enabled": true,
          "strategies": [{ "name": "default" }]
        }
      ]
    }
    WebMock.stub_request(:get, "http://test-url/client/features")
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type' => 'application/json',
          'Unleash-Appname' => 'my-test-app',
          'Unleash-Instanceid' => 'rspec/test',
          'Unleash-Connection-Id' => fixed_uuid,
          'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
          'Unleash-Sdk' => "unleash-client-ruby:#{Unleash::VERSION}",
          'X-Api-Key' => '123',
          'Unleash-Interval' => '15'
        }
      )
      .to_return(status: 200, body: simple_features.to_json, headers: {})

    Unleash.configure do |config|
      config.url      = 'http://test-url/'
      config.app_name = 'my-test-app'
      config.instance_id = 'rspec/test'
      config.custom_http_headers = { 'X-API-KEY' => '123' }
    end

    unleash_client = Unleash::Client.new(
      url: 'http://test-url/',
      app_name: 'my-test-app',
      instance_id: 'rspec/test',
      custom_http_headers: { 'X-API-KEY' => '123' }
    )

    expect(unleash_client).to be_a(Unleash::Client)

    expect(
      a_request(:post, "http://test-url/client/register")
      .with(headers: { 'Content-Type': 'application/json' })
      .with(headers: { 'X-API-KEY': '123', 'Content-Type': 'application/json' })
      .with(headers: { 'UNLEASH-APPNAME': 'my-test-app' })
      .with(headers: { 'UNLEASH-INSTANCEID': 'rspec/test' })
      .with(headers: { 'UNLEASH-CONNECTION-ID': fixed_uuid })
    ).to have_been_made.once

    expect(
      a_request(:get, "http://test-url/client/features")
      .with(headers: { 'X-API-KEY': '123' })
      .with(headers: { 'UNLEASH-APPNAME': 'my-test-app' })
      .with(headers: { 'UNLEASH-INSTANCEID': 'rspec/test' })
      .with(headers: { 'UNLEASH-CONNECTION-ID': fixed_uuid })
      .with(headers: { 'UNLEASH-INTERVAL': '15' })
    ).to have_been_made.once

    # Test now sending of metrics
    # Not sending metrics, if no feature flags were evaluated:
    Unleash.reporter.post
    expect(
      a_request(:post, "http://test-url/client/metrics")
        .with(headers: { 'Content-Type': 'application/json' })
        .with(headers: { 'X-API-KEY': '123', 'Content-Type': 'application/json' })
        .with(headers: { 'UNLEASH-APPNAME': 'my-test-app' })
        .with(headers: { 'UNLEASH-INSTANCEID': 'rspec/test' })
        .with(headers: { 'UNLEASH-CONNECTION-ID': fixed_uuid })
        .with(headers: { 'UNLEASH-INTERVAL': '60' })
    ).not_to have_been_made

    # Sending metrics, if they have been evaluated:
    unleash_client.is_enabled?("Feature.A")
    unleash_client.get_variant("Feature.A")
    Unleash.reporter.post
    expect(
      a_request(:post, "http://test-url/client/metrics")
      .with(headers: { 'Content-Type': 'application/json' })
      .with(headers: { 'X-API-KEY': '123', 'Content-Type': 'application/json' })
      .with(headers: { 'UNLEASH-APPNAME': 'my-test-app' })
      .with(headers: { 'UNLEASH-INSTANCEID': 'rspec/test' })
      .with(headers: { 'UNLEASH-CONNECTION-ID': fixed_uuid })
      .with(headers: { 'UNLEASH-INTERVAL': '60' })
      .with{ |request| JSON.parse(request.body)['bucket']['toggles']['Feature.A']['yes'] == 2 }
    ).to have_been_made.once
  end

  it "should load/use correct variants from the unleash server" do
    WebMock.stub_request(:post, "http://test-url/client/register")
      .with(
        headers: {
          'Accept' => '*/*',
          'Content-Type' => 'application/json',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Unleash-Appname' => 'my-test-app',
          'Unleash-Instanceid' => 'rspec/test',
          'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
          'Unleash-Sdk' => "unleash-client-ruby:#{Unleash::VERSION}",
          'X-Api-Key' => '123'
        }
      )
      .to_return(status: 200, body: "", headers: {})

    features_response_body = '{
      "version": 1,
      "features": [
        "name": "toggleName",
        "enabled": true,
        "strategies": [{ "name": "default" }],
        "variants": [
          {
            "name": "a",
            "weight": 50,
            "payload": {
              "type": "string",
              "value": ""
            }
          },
          {
            "name": "b",
            "weight": 50,
            "payload": {
              "type": "string",
              "value": ""
            }
          }
        ]
      ]
    }'

    WebMock.stub_request(:get, "http://test-url/client/features")
      .with(
        headers: {
          'Accept' => '*/*',
          'Content-Type' => 'application/json',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Unleash-Appname' => 'my-test-app',
          'Unleash-Instanceid' => 'rspec/test',
          'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
          'Unleash-Sdk' => "unleash-client-ruby:#{Unleash::VERSION}",
          'X-Api-Key' => '123',
          'Unleash-Interval' => '15'
        }
      )
      .to_return(status: 200, body: features_response_body, headers: {})

    Unleash.configure do |config|
      config.url      = 'http://test-url/'
      config.app_name = 'my-test-app'
      config.instance_id = 'rspec/test'
      config.disable_metrics = true
      config.custom_http_headers = { 'X-API-KEY' => '123' }
      config.log_level = Logger::DEBUG
    end

    unleash_client = Unleash::Client.new

    expect(
      unleash_client.is_enabled?('toggleName', {}, true)
    ).to eq(true)

    expect(WebMock).not_to have_requested(:get, 'http://test-url/')
    expect(WebMock).to have_requested(:post, 'http://test-url/client/register')
    expect(WebMock).to have_requested(:get, 'http://test-url/client/features')
  end

  it "should load/use correct variants from a bootstrap source" do
    bootstrap_values = '{
      "version": 1,
      "features": [
        {
          "name": "featureX",
          "enabled": true,
          "strategies": [{ "name": "default" }]
        },
        {
          "enabled": true,
          "name": "featureVariantX",
          "strategies": [{ "name": "default" }],
          "variants": [
            {
              "name": "default-value",
              "payload": {
                "type": "string",
                "value": "info"
              },
              "stickiness": "custom_attribute",
              "weight": 100,
              "weightType": "variable"
            }
          ]
        }
      ]
    }'

    Unleash.configure do |config|
      config.url      = 'http://test-url/'
      config.app_name = 'my-test-app'
      config.instance_id = 'rspec/test'
      config.disable_client = true
      config.disable_metrics = true
      config.custom_http_headers = { 'X-API-KEY' => '123' }
      config.log_level = Logger::DEBUG
      config.bootstrap_config = Unleash::Bootstrap::Configuration.new({ 'data' => bootstrap_values })
    end

    expect(Unleash.configuration.bootstrap_config.data).to eq(bootstrap_values)

    unleash_client = Unleash::Client.new
    expect(
      unleash_client.is_enabled?('featureX', {}, false)
    ).to be true

    default_variant = Unleash::Variant.new(
      name: 'featureVariantX',
      enabled: false,
      payload: { type: 'string', value: 'bogus' }
    )
    variant = unleash_client.get_variant('featureVariantX', nil, default_variant)
    expect(variant.enabled).to be true
    expect(variant.payload.fetch('value')).to eq('info')

    expect(WebMock).not_to have_requested(:get, 'http://test-url/')
    expect(WebMock).not_to have_requested(:post, 'http://test-url/client/register')
    expect(WebMock).not_to have_requested(:get, 'http://test-url/client/features')

    # No requests at all:
    expect(WebMock).not_to have_requested(:get, /.*/)
    expect(WebMock).not_to have_requested(:post, /.*/)
  end

  it "should not fail if we are provided no toggles from the unleash server" do
    WebMock.stub_request(:post, "http://test-url/client/register")
      .with(
        headers: {
          'Accept' => '*/*',
          'Content-Type' => 'application/json',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
          'Unleash-Sdk' => "unleash-client-ruby:#{Unleash::VERSION}",
          'X-Api-Key' => '123'
        }
      )
      .to_return(status: 200, body: "", headers: {})

    WebMock.stub_request(:get, "http://test-url/client/features")
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type' => 'application/json',
          'Unleash-Appname' => 'my-test-app',
          'Unleash-Instanceid' => 'rspec/test',
          'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
          'Unleash-Sdk' => "unleash-client-ruby:#{Unleash::VERSION}",
          'X-Api-Key' => '123',
          'Unleash-Interval' => '15'
        }
      )
      .to_return(status: 200, body: "", headers: {})

    Unleash.configure do |config|
      config.url      = 'http://test-url/'
      config.app_name = 'my-test-app'
      config.instance_id = 'rspec/test'
      config.disable_client = false
      config.disable_metrics = true
      config.custom_http_headers = { 'X-API-KEY' => '123' }
    end

    unleash_client = Unleash::Client.new

    expect(
      unleash_client.is_enabled?('any_feature', {}, true)
    ).to eq(true)

    expect(WebMock).not_to have_requested(:get, 'http://test-url/')
    expect(WebMock).to have_requested(:get, 'http://test-url/client/features')
    expect(WebMock).to have_requested(:post, 'http://test-url/client/register')
    expect(WebMock).not_to have_requested(:post, 'http://test-url/client/metrics')
  end

  it "should not fail if we are provided no variants from the unleash server" do
    WebMock.stub_request(:post, "http://test-url/client/register")
      .with(
        headers: {
          'Accept' => '*/*',
          'Content-Type' => 'application/json',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
          'Unleash-Sdk' => "unleash-client-ruby:#{Unleash::VERSION}",
          'X-Api-Key' => '123'
        }
      )
      .to_return(status: 200, body: "", headers: {})

    features_response_body = '{
      "version": 1,
      "features": [{
        "name": "toggleName",
        "enabled": true,
        "strategies": [{ "name": "default", "constraints": [], "parameters": {}, "variants": null }],
        "variants": []
      }]
    }'

    WebMock.stub_request(:get, "http://test-url/client/features")
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type' => 'application/json',
          'Unleash-Appname' => 'my-test-app',
          'Unleash-Instanceid' => 'rspec/test',
          'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
          'Unleash-Sdk' => "unleash-client-ruby:#{Unleash::VERSION}",
          'X-Api-Key' => '123',
          'Unleash-Interval' => '15'
        }
      )
      .to_return(status: 200, body: features_response_body, headers: {})

    Unleash.configure do |config|
      config.url      = 'http://test-url/'
      config.app_name = 'my-test-app'
      config.instance_id = 'rspec/test'
      config.disable_client = false
      config.disable_metrics = true
      config.custom_http_headers = { 'X-API-KEY' => '123' }
    end

    unleash_client = Unleash::Client.new

    expect(unleash_client.is_enabled?('toggleName', {})).to be true

    expect(WebMock).not_to have_requested(:get, 'http://test-url/')
    expect(WebMock).to have_requested(:get, 'http://test-url/client/features')
    expect(WebMock).to have_requested(:post, 'http://test-url/client/register')
    expect(WebMock).not_to have_requested(:post, 'http://test-url/client/metrics')
  end

  it "should forcefully disable metrics if the client is disabled" do
    Unleash.configure do |config|
      config.url      = 'http://test-url/'
      config.app_name = 'my-test-app'
      config.instance_id = 'rspec/test'
      config.disable_client = true
      config.disable_metrics = false
      config.custom_http_headers = { 'X-API-KEY' => '123' }
    end

    unleash_client = Unleash::Client.new

    expect(
      unleash_client.is_enabled?('any_feature', {}, true)
    ).to eq(true)

    expect(Unleash.configuration.disable_client).to be true
    expect(Unleash.configuration.disable_metrics).to be true

    # No requests at all:
    expect(WebMock).not_to have_requested(:get, /.*/)
    expect(WebMock).not_to have_requested(:post, /.*/)
  end

  it "should return default results via block or param if running with disable_client" do
    Unleash.configure do |config|
      config.disable_client = true
    end
    unleash_client = Unleash::Client.new

    expect(
      unleash_client.is_enabled?('any_feature')
    ).to be false

    expect(
      unleash_client.is_enabled?('any_feature', {}, true)
    ).to be true

    expect(
      unleash_client.is_enabled?('any_feature2', {}, false)
    ).to be false

    expect(
      unleash_client.is_enabled?('any_feature3') { true }
    ).to be true

    expect(
      unleash_client.is_enabled?('any_feature3') { false }
    ).to be false

    expect(
      unleash_client.is_enabled?('any_feature3', {}) { true }
    ).to be true

    expect(
      unleash_client.is_enabled?('any_feature3', {}) { false }
    ).to be false

    expect(
      unleash_client.is_enabled?('any_feature5', {}) { nil }
    ).to be false

    # should never really send both the default value and a default block,
    # but if it is done, we OR the two values
    expect(
      unleash_client.is_enabled?('any_feature3', {}, true) { true }
    ).to be true

    expect(
      unleash_client.is_enabled?('any_feature3', {}, false) { true }
    ).to be true

    expect(
      unleash_client.is_enabled?('any_feature3', {}, true) { false }
    ).to be true

    expect(
      unleash_client.is_enabled?('any_feature3', {}, false) { false }
    ).to be false

    expect(
      unleash_client.is_enabled?('any_feature5', {}) { 'random_string' }
    ).to be true # expect "a string".to be_truthy

    expect do |b|
      unleash_client.is_enabled?('any_feature3', &b).to yield_with_no_args
    end

    expect do |b|
      unleash_client.is_enabled?('any_feature3', {}, &b).to yield_with_no_args
    end

    expect do |b|
      unleash_client.is_enabled?('any_feature3', {}, true, &b).to yield_with_no_args
    end

    number_eight = 8
    expect(
      unleash_client.is_enabled?('any_feature5', {}) do
        number_eight >= 5
      end
    ).to be true

    expect(
      unleash_client.is_enabled?('any_feature5', {}) do
        number_eight < 5
      end
    ).to be false

    context_params = {
      session_id: 'verylongsesssionid',
      remote_address: '127.0.0.2',
      properties: {
        env: 'dev'
      }
    }
    unleash_context = Unleash::Context.new(context_params)
    expect(
      unleash_client.is_enabled?('any_feature6', unleash_context) do |feature, context|
        feature == 'any_feature6' && \
        context.remote_address == '127.0.0.2' && context.session_id.length == 18 && context.properties[:env] == 'dev'
      end
    ).to be true

    proc = proc do |_feat, ctx|
      ctx.remote_address.starts_with?("127.0.0.")
    end
    expect(
      unleash_client.is_enabled?('any_feature6', unleash_context) { proc }
    ).to be true
    expect(
      unleash_client.is_enabled?('any_feature6', unleash_context, true) { proc }
    ).to be true
    expect(
      unleash_client.is_enabled?('any_feature6', unleash_context, false) { proc }
    ).to be true

    proc_feat = proc do |feat, _ctx|
      feat != 'feature6'
    end
    expect(
      unleash_client.is_enabled?('feature6', unleash_context, &proc_feat)
    ).to be false
    expect(
      unleash_client.is_enabled?('feature6', unleash_context, true, &proc_feat)
    ).to be true
    expect(
      unleash_client.is_enabled?('feature6', unleash_context, false, &proc_feat)
    ).to be false
  end

  it "should not connect anywhere if running with disable_client" do
    Unleash.configure do |config|
      config.disable_client = true
      config.url = 'http://test-url/'
      config.custom_http_headers = 'invalid_string'
    end

    unleash_client = Unleash::Client.new

    expect(
      unleash_client.is_enabled?('any_feature', {}, true)
    ).to eq(true)

    expect(WebMock).not_to have_requested(:get, 'http://test-url/')
    expect(WebMock).not_to have_requested(:get, 'http://test-url/client/features')
    expect(WebMock).not_to have_requested(:post, 'http://test-url/client/features')
    expect(WebMock).not_to have_requested(:post, 'http://test-url/client/register')
    expect(WebMock).not_to have_requested(:post, 'http://test-url/client/metrics')
  end

  it "should return correct default values" do
    unleash_client = Unleash::Client.new
    expect(unleash_client.is_enabled?('any_feature')).to eq(false)
    expect(unleash_client.is_enabled?('any_feature', {}, false)).to eq(false)
    expect(unleash_client.is_enabled?('any_feature', {}, true)).to eq(true)

    expect(unleash_client.enabled?('any_feature', {}, true)).to eq(true)
    expect(unleash_client.enabled?('any_feature', {}, false)).to eq(false)

    expect(unleash_client.is_disabled?('any_feature')).to eq(true)
    expect(unleash_client.is_disabled?('any_feature', {}, true)).to eq(true)
    expect(unleash_client.is_disabled?('any_feature', {}, false)).to eq(false)

    expect(unleash_client.disabled?('any_feature', {}, true)).to eq(true)
    expect(unleash_client.disabled?('any_feature', {}, false)).to eq(false)
  end

  it "should yield correctly to block when using if_enabled" do
    unleash_client = Unleash::Client.new
    cont = Unleash::Context.new(user_id: 1)

    expect{ |b| unleash_client.if_enabled('any_feature', {}, true, &b).to yield_with_no_args }
    expect{ |b| unleash_client.if_enabled('any_feature', cont, true, &b).to yield_with_no_args }
    expect{ |b| unleash_client.if_enabled('any_feature', {}, false, &b).not_to yield_with_no_args }
  end

  it "should yield correctly to block when using if_disabled" do
    unleash_client = Unleash::Client.new
    cont = Unleash::Context.new(user_id: 1)

    expect{ |b| unleash_client.if_disabled('any_feature', {}, true, &b).not_to yield_with_no_args }
    expect{ |b| unleash_client.if_disabled('any_feature', cont, true, &b).not_to yield_with_no_args }

    expect{ |b| unleash_client.if_disabled('any_feature', {}, false, &b).to yield_with_no_args }
    expect{ |b| unleash_client.if_disabled('any_feature', cont, false, &b).to yield_with_no_args }
    expect{ |b| unleash_client.if_disabled('any_feature', {}, &b).to yield_with_no_args }
    expect{ |b| unleash_client.if_disabled('any_feature', &b).to yield_with_no_args }
  end

  describe 'get_variant' do
    let(:disable_client) { false }
    let(:client) { Unleash::Client.new }
    let(:feature) { 'awesome-feature' }
    let(:fallback_variant) { Unleash::Variant.new(name: 'default', enabled: true) }
    let(:variants) do
      [
        {
          name: "a",
          weight: 50,
          stickiness: "default",
          payload: {
            type: "string",
            value: ""
          }
        }
      ]
    end
    let(:body) do
      {
        version: 1,
        features: [
          {
            name: feature,
            enabled: true,
            strategies: [
              { name: "default" }
            ],
            variants: variants
          }
        ]
      }.to_json
    end

    before do
      WebMock.stub_request(:post, "http://test-url/client/register")
        .with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Content-Type' => 'application/json',
            'Unleash-Appname' => 'my-test-app',
            'Unleash-Instanceid' => 'rspec/test',
            'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
            'Unleash-Sdk' => "unleash-client-ruby:#{Unleash::VERSION}",
            'X-Api-Key' => '123'
          }
        )
        .to_return(status: 200, body: '', headers: {})

      WebMock.stub_request(:get, "http://test-url/client/features")
        .with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Content-Type' => 'application/json',
            'Unleash-Appname' => 'my-test-app',
            'Unleash-Instanceid' => 'rspec/test',
            'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]",
            'Unleash-Sdk' => "unleash-client-ruby:#{Unleash::VERSION}",
            'X-Api-Key' => '123',
            'Unleash-Interval' => '15'
          }
        )
        .to_return(status: 200, body: body, headers: {})

      Unleash.configure do |config|
        config.url      = 'http://test-url/'
        config.app_name = 'my-test-app'
        config.disable_client = disable_client
        config.custom_http_headers = { 'X-API-KEY' => '123' }
      end
    end

    it 'returns variant' do
      ret = client.get_variant(feature)
      expect(ret.name).to eq 'a'
    end

    context 'when disable_client is false' do
      let(:disable_client) { true }

      context 'when fallback variant is specified' do
        it 'returns given fallback variant' do
          expect(client.get_variant(feature, nil, fallback_variant)).to be fallback_variant
        end
      end

      context 'when fallback variant is not specified' do
        it 'returns a disabled variant' do
          ret = client.get_variant(feature)
          expect(ret.enabled).to be false
          expect(ret.name).to eq 'disabled'
        end
      end
    end

    context 'when feature is not found' do
      context 'when fallback variant is specified' do
        it 'returns given fallback variant' do
          expect(client.get_variant('something', nil, fallback_variant)).to be fallback_variant
        end
      end

      context 'when fallback variant is not specified' do
        it 'returns a disabled variant' do
          ret = client.get_variant('something')
          expect(ret.enabled).to be false
          expect(ret.name).to eq 'disabled'
        end
      end
    end

    context 'when feature does not have variants' do
      let(:variants) { [] }

      it 'returns a disabled variant' do
        ret = client.get_variant(feature)
        expect(ret.enabled).to be false
        expect(ret.name).to eq 'disabled'
      end
    end
  end

  it "should use custom strategies during evaluation" do
    bootstrap_values = '{
      "version": 1,
      "features": [
        {
          "name": "featureX",
          "enabled": true,
          "strategies": [{ "name": "customStrategy" }]
        }
      ]
    }'

    class TestStrategy
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def enabled?(_params, context)
        context.user_id == "123"
      end
    end

    Unleash.configure do |config|
      config.app_name = 'my-test-app'
      config.instance_id = 'rspec/test'
      config.disable_client = true
      config.disable_metrics = true
      config.bootstrap_config = Unleash::Bootstrap::Configuration.new({ 'data' => bootstrap_values })
      config.strategies.add(TestStrategy.new('customStrategy'))
    end

    context_params = {
      user_id: '123'
    }
    unleash_context = Unleash::Context.new(context_params)

    unleash_client = Unleash::Client.new
    expect(
      unleash_client.is_enabled?('featureX', unleash_context)
    ).to be true

    expect(
      unleash_client.is_enabled?('featureX', Unleash::Context.new({}))
    ).to be false
  end

  unless RUBY_ENGINE == 'jruby'
    describe "streaming mode" do
      it "should process unleash-connected event" do
        WebMock.stub_request(:post, "http://test-url/client/register")
          .to_return(status: 200, body: "", headers: {})

        sse_response_body = <<~SSE
          event: unleash-connected
          data: {"events":[{"type":"hydration","eventId":1,"features":[{"name":"test-feature","enabled":true,"strategies":[{"name":"default"}]}],"segments":[]}]}

        SSE

        WebMock.stub_request(:get, "http://test-url/client/streaming")
          .with(headers: { 'X-API-KEY' => '123' })
          .to_return(
            status: 200,
            body: sse_response_body,
            headers: { 'Content-Type' => 'text/event-stream' }
          )

        Unleash.configure do |config|
          config.url = 'http://test-url/'
          config.app_name = 'my-test-app'
          config.instance_id = 'rspec/test'
          config.disable_metrics = true
          config.custom_http_headers = { 'X-API-KEY' => '123' }
          config.experimental_mode = { type: 'streaming' }
        end

        unleash_client = Unleash::Client.new

        sleep(0.1)

        expect(WebMock).to have_requested(:get, "http://test-url/client/streaming")
          .with(headers: { 'X-API-KEY' => '123' })

        expect(unleash_client.is_enabled?('test-feature')).to be true

        unleash_client.shutdown!
      end

      it "should process unleash-updated event" do
        WebMock.stub_request(:post, "http://test-url/client/register")
          .to_return(status: 200, body: "", headers: {})

        sse_response_body = <<~SSE
          event: unleash-updated
          data: {"events":[{"type":"feature-updated","eventId":2,"feature":{"name":"test-feature","enabled":true,"strategies":[{"name":"default"}]}}]}

        SSE

        WebMock.stub_request(:get, "http://test-url/client/streaming")
          .with(headers: { 'X-API-KEY' => '123' })
          .to_return(
            status: 200,
            body: sse_response_body,
            headers: { 'Content-Type' => 'text/event-stream' }
          )

        Unleash.configure do |config|
          config.url = 'http://test-url/'
          config.app_name = 'my-test-app'
          config.instance_id = 'rspec/test'
          config.disable_metrics = true
          config.custom_http_headers = { 'X-API-KEY' => '123' }
          config.experimental_mode = { type: 'streaming' }
        end

        unleash_client = Unleash::Client.new

        expect(unleash_client.streaming_client).to be_a(Unleash::StreamingClient)
        expect(unleash_client.streaming_client.running?).to be true

        sleep(0.1)

        expect(WebMock).to have_requested(:get, "http://test-url/client/streaming")
          .with(headers: { 'X-API-KEY' => '123' })

        expect(unleash_client.is_enabled?('test-feature')).to be true

        unleash_client.shutdown!
      end
    end
  end
end
