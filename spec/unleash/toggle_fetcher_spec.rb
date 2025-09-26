RSpec.describe Unleash::ToggleFetcher do
  subject(:toggle_fetcher) { Unleash::ToggleFetcher.new YggdrasilEngine.new }

  before do
    Unleash.configure do |config|
      config.url      = 'http://toggle-fetcher-test-url/'
      config.app_name = 'toggle-fetcher-my-test-app'
      config.disable_client = false # Some test is changing the process state for this one
    end

    fetcher_features = {
      "version": 1,
      "features": [
        {
          "name": "Feature.A",
          "description": "Enabled toggle",
          "enabled": true,
          "strategies": [{ "name": "toggle-fetcher" }]
        }
      ],
      "segments": [
        {
          "id": 1,
          "name": "test-segment",
          "description": "test-segment",
          "constraints": [
            {
              "values": [
                "7"
              ],
              "inverted": false,
              "operator": "IN",
              "contextName": "test",
              "caseInsensitive": false
            }
          ],
          "createdBy": "admin",
          "createdAt": "2022-09-02T00:00:00.000Z"
        }
      ]

    }

    WebMock.stub_request(:get, "http://toggle-fetcher-test-url/client/features")
      .to_return(status: 200,
                 body: fetcher_features.to_json,
                 headers: {})

    Unleash.logger = Unleash.configuration.logger
  end

  after do
    WebMock.reset!
    File.delete(Unleash.configuration.backup_file) if File.exist?(Unleash.configuration.backup_file)
  end

  describe '#fetch!' do
    let(:engine) { YggdrasilEngine.new }

    context 'when fetching toggles succeeds' do
      before do
        _toggle_fetcher = described_class.new engine
      end
      it 'creates a file with toggle_cache in JSON' do
        backup_file = Unleash.configuration.backup_file
        expect(File.exist?(backup_file)).to eq(true)
      end

      # NOTE: this is a frequent issue with Puma (in clustered mode). See Unleash/unleash-ruby-sdk#108
      it 'does not log errors due to concurrent forked processes' do
        skip 'Fork not supported on current platform' unless Process.respond_to?(:fork)

        log_file = ->(pid) { File.join(Dir.tmpdir, "#{pid}.log") }
        pids = Array.new(10) do
          fork do
            Unleash.logger = Logger.new(log_file.call(Process.pid))
            expect(Unleash.logger).not_to receive(:error)
            described_class.new engine
          end
        end

        pids.each do |pid|
          Process.wait(pid)
          process_status = $? # rubocop:disable Style/SpecialGlobalVars
          error_log_file = log_file.call(pid)
          expect(File.exist?(error_log_file))

          error_msg = "Process #{pid} failed with errors:\n#{File.read(error_log_file).lines[1..].join}"
          expect(process_status).to be_success, error_msg
        end
      end
    end
  end

  describe '.new' do
    let(:engine) { YggdrasilEngine.new }
    context 'when there are problems fetching toggles' do
      before do
        backup_file = Unleash.configuration.backup_file

        toggles = {
          version: 2,
          features: [
            {
              name: "Feature.A",
              description: "Enabled toggle",
              enabled: true,
              strategies: [{
                "name": "default"
              }]
            }
          ]
        }

        # manually create a stub cache on disk, so we can test that we read it correctly later.
        File.open(backup_file, "w") do |file|
          file.write(toggles.to_json)
        end

        WebMock.stub_request(:get, "http://toggle-fetcher-test-url/client/features").to_return(status: 500)
        _toggle_fetcher = described_class.new engine # we new up a new toggle fetcher so that engine is synced
      end

      it 'reads the backup file for values' do
        enabled = engine.enabled?('Feature.A', {})
        expect(enabled).to eq(true)
      end
    end
  end
end
