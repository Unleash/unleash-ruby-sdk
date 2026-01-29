RSpec.describe Unleash::EnvironmentResolver do
  describe '.extract_environment_from_custom_headers' do
    it 'extracts environment from valid headers' do
      headers = {
        'Authorization' => 'project:environment.hash',
        'Content-Type' => 'application/json'
      }

      result = Unleash::EnvironmentResolver.extract_environment_from_custom_headers(headers)
      expect(result).to eq('environment')
    end

    it 'handles case-insensitive header keys' do
      headers = {
        'AUTHORIZATION' => 'project:environment.hash',
        'Content-Type' => 'application/json'
      }

      result = Unleash::EnvironmentResolver.extract_environment_from_custom_headers(headers)
      expect(result).to eq('environment')
    end

    it 'returns nil when authorization header not present' do
      result = Unleash::EnvironmentResolver.extract_environment_from_custom_headers({})
      expect(result).to be_nil
    end

    it 'returns nil when environment part is empty' do
      headers = {
        'Authorization' => 'project:.hash'
      }

      result = Unleash::EnvironmentResolver.extract_environment_from_custom_headers(headers)
      expect(result).to be_nil
    end

    it 'returns nil when headers is nil' do
      result = Unleash::EnvironmentResolver.extract_environment_from_custom_headers(nil)
      expect(result).to be_nil
    end

    it 'returns nil when no colon in authorization value' do
      headers = {
        'Authorization' => 'invalid-token'
      }

      result = Unleash::EnvironmentResolver.extract_environment_from_custom_headers(headers)
      expect(result).to be_nil
    end

    it 'returns nil when no dot after colon' do
      headers = {
        'Authorization' => 'project:environment'
      }

      result = Unleash::EnvironmentResolver.extract_environment_from_custom_headers(headers)
      expect(result).to be_nil
    end
  end
end
