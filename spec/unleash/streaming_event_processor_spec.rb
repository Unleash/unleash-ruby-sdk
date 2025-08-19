RSpec.describe Unleash::StreamingEventProcessor do
  let(:engine) { YggdrasilEngine.new }
  let(:processor) { Unleash::StreamingEventProcessor.new(engine) }
  let(:backup_file) { Unleash.configuration.backup_file }

  before do
    Unleash.configure do |config|
      config.url = 'http://test-url/'
      config.app_name = 'test-app'
    end
    Unleash.logger = Unleash.configuration.logger
  end

  after do
    File.delete(backup_file) if File.exist?(backup_file)
  end

  class TestEvent
    attr_reader :type, :data
    
    def initialize(type, data)
      @type = type
      @data = data
    end
  end

  def feature_event(name, enabled = true)
    {
      "events": [{
        "type": "feature-updated",
        "eventId": 1,
        "feature": {
          "name": name,
          "enabled": enabled,
          "strategies": [{"name": "default"}]
        }
      }]
    }.to_json
  end

  def backup_contains_feature?(name)
    return false unless File.exist?(backup_file)
    parsed = JSON.parse(File.read(backup_file))
    feature_names = parsed['features'].map { |f| f['name'] }
    feature_names.include?(name)
  end

  describe '#process_event' do

    it 'processes valid events and saves full engine state' do
      event = TestEvent.new('unleash-updated', feature_event('test-feature'))
      processor.process_event(event)
      
      expect(engine.enabled?('test-feature', {})).to eq(true)
      expect(backup_contains_feature?('test-feature')).to eq(true)
    end


    it 'ignores unknown event types' do
      event = TestEvent.new('unknown-event', feature_event('test-feature'))
      processor.process_event(event)
      
      expect(File.exist?(backup_file)).to eq(false)
      expect(engine.enabled?('test-feature', {})).to be_falsy
    end

    it 'saves full engine state, not partial event data' do
      processor.process_event(TestEvent.new('unleash-updated', feature_event('first-feature', true)))
      processor.process_event(TestEvent.new('unleash-updated', feature_event('second-feature', false)))

      expect(backup_contains_feature?('first-feature')).to eq(true)
      expect(backup_contains_feature?('second-feature')).to eq(true)
    end

    it 'handles invalid JSON gracefully without creating backup' do
      event = TestEvent.new('unleash-updated', 'invalid json')
      
      expect { processor.process_event(event) }.not_to raise_error
      expect(File.exist?(backup_file)).to eq(false)
    end
  end
end