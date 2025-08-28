RSpec.describe Unleash::StreamingClientExecutor do
  unless RUBY_ENGINE == 'jruby'
    before do
      Unleash.configure do |config|
        config.url      = 'http://streaming-test-url/'
        config.app_name = 'streaming-test-app'
        config.instance_id = 'rspec/streaming'
        config.disable_metrics = true
        config.experimental_mode = { type: 'streaming' }
      end

      WebMock.stub_request(:post, "http://streaming-test-url/client/register")
        .to_return(status: 200, body: "", headers: {})

      Unleash.logger = Unleash.configuration.logger
    end

    after do
      WebMock.reset!
      File.delete(Unleash.configuration.backup_file) if File.exist?(Unleash.configuration.backup_file)

      # Reset configuration to prevent interference with other tests
      Unleash.configuration.bootstrap_config = nil
      Unleash.configuration.experimental_mode = nil
      Unleash.configuration.disable_metrics = false
    end

    describe '.new' do
      let(:engine) { YggdrasilEngine.new }
      let(:executor_name) { 'streaming_client_executor_spec' }

      context 'when there are problems connecting to streaming endpoint' do
        let(:backup_toggles) do
          {
            version: 1,
            features: [
              {
                name: "backup-feature",
                description: "Feature from backup",
                enabled: true,
                strategies: [{
                  "name": "default"
                }]
              }
            ]
          }
        end

        let(:streaming_executor) { described_class.new(executor_name, engine) }

        before do
          backup_file = Unleash.configuration.backup_file

          # manually create a stub cache on disk, so we can test that we read it correctly later.
          File.open(backup_file, "w") do |file|
            file.write(backup_toggles.to_json)
          end

          # Simulate streaming connection failure
          WebMock.stub_request(:get, "http://streaming-test-url/client/streaming")
            .to_return(status: 500, body: "Internal Server Error", headers: {})

          streaming_executor
        end

        it 'reads the backup file for values' do
          enabled = engine.enabled?('backup-feature', {})
          expect(enabled).to eq(true)
        end
      end

      context 'when bootstrap is configured' do
        let(:bootstrap_data) do
          {
            version: 1,
            features: [
              {
                name: "bootstrap-feature",
                enabled: true,
                strategies: [{ name: "default" }]
              }
            ]
          }
        end

        let(:bootstrap_config) do
          Unleash::Bootstrap::Configuration.new({
            'data' => bootstrap_data.to_json
          })
        end

        let(:streaming_executor) { described_class.new(executor_name, engine) }

        before do
          Unleash.configuration.bootstrap_config = bootstrap_config

          # Streaming connection might succeed or fail, doesn't matter for bootstrap
          WebMock.stub_request(:get, "http://streaming-test-url/client/streaming")
            .to_return(status: 200, body: "", headers: {})

          streaming_executor
        end

        after do
          Unleash.configuration.bootstrap_config = nil
        end

        it 'uses bootstrap data on initialization' do
          enabled = engine.enabled?('bootstrap-feature', {})
          expect(enabled).to eq(true)
        end

        it 'clears bootstrap config after use' do
          expect(Unleash.configuration.bootstrap_config).to be_nil
        end
      end

      context 'when bootstrap fails and backup file exists' do
        let(:invalid_bootstrap_config) do
          Unleash::Bootstrap::Configuration.new({
            'data' => 'invalid json'
          })
        end

        let(:fallback_toggles) do
          {
            version: 1,
            features: [
              {
                name: "fallback-feature",
                enabled: true,
                strategies: [{ name: "default" }]
              }
            ]
          }
        end

        let(:streaming_executor) { described_class.new(executor_name, engine) }

        before do
          backup_file = Unleash.configuration.backup_file

          File.open(backup_file, "w") do |file|
            file.write(fallback_toggles.to_json)
          end

          Unleash.configuration.bootstrap_config = invalid_bootstrap_config

          # Streaming connection failure doesn't matter here
          WebMock.stub_request(:get, "http://streaming-test-url/client/streaming")
            .to_return(status: 500, body: "", headers: {})

          streaming_executor
        end

        after do
          Unleash.configuration.bootstrap_config = nil
        end

        it 'falls back to reading backup file when bootstrap fails' do
          enabled = engine.enabled?('fallback-feature', {})
          expect(enabled).to eq(true)
        end
      end
    end
  end
end
