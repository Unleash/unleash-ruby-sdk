RSpec.describe Unleash::StreamingEventProcessor do
  let(:engine) { YggdrasilEngine.new }
  let(:processor) { Unleash::StreamingEventProcessor.new(engine) }

  before do
    Unleash.configure do |config|
      config.url = 'http://streaming-test-url/'
      config.app_name = 'streaming-my-test-app'
    end

    Unleash.logger = Unleash.configuration.logger
  end

  after do
    WebMock.reset!
    File.delete(Unleash.configuration.backup_file) if File.exist?(Unleash.configuration.backup_file)
  end

  describe '#process_event' do
    let(:updated_event_data) do
      {
        "events": [
          {
            "type": "feature-updated",
            "eventId": 2,
            "feature": {
              "name": "test-feature",
              "enabled": true,
              "strategies": [{"name": "default"}]
            }
          }
        ]
      }.to_json
    end

    let(:connected_event_data) do
      {
        "events": [
          {
            "type": "hydration",
            "eventId": 1,
            "features": [
              {
                "name": "test-feature",
                "enabled": true,
                "strategies": [{"name": "default"}]
              }
            ],
            "segments": []
          }
        ]
      }.to_json
    end

    class TestEvent
      attr_reader :type, :data
      
      def initialize(type, data)
        @type = type
        @data = data
      end
    end

    context 'when processing unleash-updated event' do
      let(:event) { TestEvent.new('unleash-updated', updated_event_data) }

      it 'creates a backup file with toggle data' do
        processor.process_event(event)

        backup_file = Unleash.configuration.backup_file
        expect(File.exist?(backup_file)).to eq(true)

        content = File.read(backup_file)
        expect(content).to eq(updated_event_data)

        parsed = JSON.parse(content)
        expect(parsed).to include('events')
        expect(parsed['events'].first).to include('feature')
        expect(parsed['events'].first['feature']['name']).to eq('test-feature')
      end

      it 'updates the engine state' do
        processor.process_event(event)
        
        expect(engine.enabled?('test-feature', {})).to eq(true)
      end
    end

    context 'when processing unleash-connected event' do
      let(:event) { TestEvent.new('unleash-connected', connected_event_data) }

      it 'creates a backup file with toggle data' do
        processor.process_event(event)

        backup_file = Unleash.configuration.backup_file
        expect(File.exist?(backup_file)).to eq(true)

        content = File.read(backup_file)
        expect(content).to eq(connected_event_data)

        parsed = JSON.parse(content)
        expect(parsed).to include('events')
        expect(parsed['events'].first).to include('features')
        expect(parsed['events'].first['features'].first['name']).to eq('test-feature')
      end

      it 'updates the engine state' do
        processor.process_event(event)
        
        expect(engine.enabled?('test-feature', {})).to eq(true)
      end
    end

    context 'when processing unknown event type' do
      let(:event) { TestEvent.new('unknown-event', updated_event_data) }

      it 'does not create a backup file' do
        processor.process_event(event)

        backup_file = Unleash.configuration.backup_file
        expect(File.exist?(backup_file)).to eq(false)
      end

      it 'does not update the engine state' do
        initial_enabled = engine.enabled?('test-feature', {})
        
        processor.process_event(event)
        
        expect(engine.enabled?('test-feature', {})).to eq(initial_enabled)
      end
    end

    context 'when processing event with invalid JSON' do
      let(:invalid_data) { 'invalid json data that looks like real streaming data but is malformed' }
      let(:event) { TestEvent.new('unleash-updated', invalid_data) }

      it 'handles JSON parse errors gracefully' do
        expect { processor.process_event(event) }.not_to raise_error
      end

      it 'still creates a backup file with the raw data' do
        processor.process_event(event)

        backup_file = Unleash.configuration.backup_file
        expect(File.exist?(backup_file)).to eq(true)

        content = File.read(backup_file)
        expect(content).to eq(invalid_data)
      end
    end
  end
end