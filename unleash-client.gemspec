lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'unleash/version'

Gem::Specification.new do |spec|
  spec.name          = "unleash"
  spec.version       = Unleash::VERSION
  spec.authors       = ["Renato Arruda"]
  spec.email         = ["rarruda@rarruda.org"]
  spec.licenses      = ["Apache-2.0"]

  spec.summary       = "Unleash feature toggle client."
  spec.description   = "This is the ruby client for Unleash, a powerful feature toggle system
    that gives you a great overview over all feature toggles across all your applications and services."

  spec.homepage      = "https://github.com/unleash/unleash-client-ruby"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/unleash}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.7"

  spec.add_dependency "ld-eventsource", "2.2.6" unless RUBY_ENGINE == 'jruby'
  spec.add_dependency "yggdrasil-engine", "~> 1.0.4"

  spec.add_dependency "base64", "~> 0.3.0"
  spec.add_dependency "logger", "~> 1.6"

  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "rake", "~> 12.3"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rspec-json_expectations", "~> 2.2"
  spec.add_development_dependency "webmock", "~> 3.18.1"

  # rubocop:disable Gemspec/RubyVersionGlobalsUsage, Style/IfUnlessModifier
  if Gem::Version.new(RUBY_VERSION) > Gem::Version.new('3.0')
    spec.add_development_dependency "rubocop", "~> 1.75"
  end
  # rubocop:enable Gemspec/RubyVersionGlobalsUsage, Style/IfUnlessModifier

  spec.add_development_dependency "simplecov", "~> 0.21.2"
  spec.add_development_dependency "simplecov-lcov", "~> 0.8.0"
end
