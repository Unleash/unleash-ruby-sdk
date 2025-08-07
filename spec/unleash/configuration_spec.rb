require "unleash/configuration"
require "securerandom"

RSpec.describe Unleash do
  describe 'Configuration' do
    before do
      Unleash.configuration = Unleash::Configuration.new
    end

    it "should have the correct defaults" do
      config = Unleash::Configuration.new

      expect(config.app_name).to be_nil
      expect(config.environment).to eq('default')
      expect(config.url).to be_nil
      expect(config.instance_id).to be_truthy
      expect(config.custom_http_headers).to eq({})
      expect(config.disable_metrics).to be_falsey

      expect(config.refresh_interval).to eq(15)
      expect(config.metrics_interval).to eq(60)
      expect(config.timeout).to eq(30)
      expect(config.retry_limit).to eq(Float::INFINITY)

      expect(config.backup_file).to_not be_nil
      expect(config.backup_file).to eq(Dir.tmpdir + '/unleash--repo.json')
      expect(config.project_name).to be_nil

      expect(config.strategies).to be_instance_of(Unleash::Strategies)

      expect{ config.validate! }.to raise_error(ArgumentError)
    end

    it "should by default be invalid" do
      config = Unleash::Configuration.new
      expect{ config.validate! }.to raise_error(ArgumentError)
    end

    it "should be valid with the mandatory arguments set" do
      config = Unleash::Configuration.new(app_name: 'rspec_test', url: 'http://testurl/')
      expect{ config.validate! }.not_to raise_error
    end

    it "should be lenient if disable_client is true" do
      config = Unleash::Configuration.new(disable_client: true)
      expect{ config.validate! }.not_to raise_error
    end

    it "support setting the configuration via new" do
      config = Unleash::Configuration.new(app_name: 'rspec_test', url: 'http://testurl/')

      expect(config.app_name).to eq('rspec_test')
      expect(config.environment).to eq('default')
      expect(config.url).to eq('http://testurl/')
      expect(config.instance_id).to be_truthy
      expect(config.custom_http_headers).to eq({})
      expect(config.disable_metrics).to be_falsey

      expect(config.backup_file).to eq(Dir.tmpdir + '/unleash-rspec_test-repo.json')
      expect(config.project_name).to be_nil

      expect{ config.validate! }.not_to raise_error
    end

    it "support yield for setting the configuration" do
      Unleash.configure do |config|
        config.url      = 'http://test-url/'
        config.app_name = 'my-test-app'
      end
      expect{ Unleash.configuration.validate! }.not_to raise_error
      expect(Unleash.configuration.url).to eq('http://test-url/')
      expect(Unleash.configuration.app_name).to eq('my-test-app')
      expect(Unleash.configuration.backup_file).to eq(Dir.tmpdir + '/unleash-my-test-app-repo.json')
      expect(Unleash.configuration.fetch_toggles_uri.to_s).to eq('http://test-url/client/features')
      expect(Unleash.configuration.client_metrics_uri.to_s).to eq('http://test-url/client/metrics')
      expect(Unleash.configuration.client_register_uri.to_s).to eq('http://test-url/client/register')
    end

    it "should build the correct unleash endpoints from the base url" do
      config = Unleash::Configuration.new(url: 'https://testurl/api', app_name: 'test-app')
      expect(config.url).to eq('https://testurl/api')
      expect(config.fetch_toggles_uri.to_s).to eq('https://testurl/api/client/features')
      expect(config.client_metrics_uri.to_s).to eq('https://testurl/api/client/metrics')
      expect(config.client_register_uri.to_s).to eq('https://testurl/api/client/register')
    end

    it "should build the correct unleash endpoints from a base url ending with slash" do
      config = Unleash::Configuration.new(url: 'https://testurl/api/', app_name: 'test-app')
      expect(config.url).to eq('https://testurl/api/')
      expect(config.fetch_toggles_uri.to_s).to eq('https://testurl/api/client/features')
      expect(config.client_metrics_uri.to_s).to eq('https://testurl/api/client/metrics')
      expect(config.client_register_uri.to_s).to eq('https://testurl/api/client/register')
    end

    it "should build the correct unleash endpoints from a base url ending with double slashes" do
      config = Unleash::Configuration.new(url: 'https://testurl/api//', app_name: 'test-app')
      expect(config.url).to eq('https://testurl/api//')
      expect(config.fetch_toggles_uri.to_s).to eq('https://testurl/api//client/features')
      expect(config.client_metrics_uri.to_s).to eq('https://testurl/api//client/metrics')
      expect(config.client_register_uri.to_s).to eq('https://testurl/api//client/register')
    end

    it "should build the correct unleash features endpoint when project_name is used" do
      config = Unleash::Configuration.new(url: 'https://testurl/api', app_name: 'test-app', project_name: 'test-project')
      expect(config.fetch_toggles_uri.to_s).to eq('https://testurl/api/client/features?project=test-project')
    end

    it "should allow hashes for custom_http_headers via yield" do
      Unleash.configure do |config|
        config.url      = 'http://test-url/'
        config.app_name = 'my-test-app'
        config.custom_http_headers = { 'X-API-KEY': '123' }
      end
      expect{ Unleash.configuration.validate! }.not_to raise_error
      expect(Unleash.configuration.custom_http_headers).to eq({ 'X-API-KEY': '123' })
    end

    it "should allow hashes for custom_http_headers via new client" do
      config = Unleash::Configuration.new(
        url: 'https://testurl/api',
        app_name: 'test-app',
        custom_http_headers: { 'X-API-KEY': '123', 'UNLEASH-CONNECTION-ID': 'ignore' }
      )

      expect{ config.validate! }.not_to raise_error
      expect(config.custom_http_headers).to include({ 'X-API-KEY': '123' })
      expect(config.http_headers).to include({ 'UNLEASH-APPNAME' => 'test-app' })
      expect(config.http_headers).to include('UNLEASH-INSTANCEID')
      expect(config.http_headers).to include('UNLEASH-CONNECTION-ID')
    end

    it "should allow lambdas and procs for custom_https_headers via new client" do
      custom_headers_proc = proc do
        { 'X-API-KEY' => '123' }
      end
      allow(custom_headers_proc).to receive(:call).and_call_original

      fixed_uuid = "123e4567-e89b-12d3-a456-426614174000"
      allow(SecureRandom).to receive(:uuid).and_return(fixed_uuid)

      config = Unleash::Configuration.new(
        url: 'https://testurl/api',
        app_name: 'test-app',
        custom_http_headers: custom_headers_proc
      )

      expect{ config.validate! }.not_to raise_error
      expect(config.custom_http_headers).to be_a(Proc)
      expect(config.http_headers).to eq(
        {
          'X-API-KEY' => '123',
          'UNLEASH-APPNAME' => 'test-app',
          'UNLEASH-INSTANCEID' => config.instance_id,
          'UNLEASH-CONNECTION-ID' => fixed_uuid,
          'UNLEASH-SDK' => "unleash-ruby-sdk:#{Unleash::VERSION}",
          'Unleash-Client-Spec' => '5.2.0',
          'User-Agent' => "UnleashClientRuby/#{Unleash::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} [#{RUBY_PLATFORM}]"
        }
      )
      expect(custom_headers_proc).to have_received(:call).exactly(1).times
    end

    it "should not accept invalid custom_http_headers via yield" do
      expect do
        Unleash.configure do |config|
          config.url      = 'http://test-url/'
          config.app_name = 'my-test-app'
          config.custom_http_headers = 123.456
        end
      end.to raise_error(ArgumentError, "custom_http_headers must be a Hash or a Proc.")
    end

    it "should not accept invalid custom_http_headers via new client" do
      WebMock \
        .stub_request(:post, "http://test-url//client/register")
        .with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Content-Type' => 'application/json',
            'User-Agent' => 'Ruby'
          }
        )
        .to_return(status: 200, body: "", headers: {})

      expect do
        Unleash::Client.new(
          url: 'https://testurl/api',
          app_name: 'test-app',
          custom_http_headers: 123.0,
          disable_metrics: true
        )
      end.to raise_error(ArgumentError)
    end

    it "should send metadata on registration" do
      WebMock \
        .stub_request(:get, "http://test-url/api/client/features")
        .to_return(status: 200, body: "", headers: {})

      WebMock \
        .stub_request(:post, "http://test-url/api/client/register")
        .to_return(status: 200, body: "", headers: {})

      Unleash::Client.new(
        url: 'http://test-url/api',
        app_name: 'test-app'
      )

      expect(WebMock).to have_requested(:post, 'http://test-url/api/client/register')
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
end
