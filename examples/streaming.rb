#!/usr/bin/env ruby

require 'unleash'
require 'unleash/context'

puts ">> START streaming.rb"

@unleash = Unleash::Client.new(
  url: 'https://app.unleash-hosted.com/demo/api',
  custom_http_headers: { 'Authorization': 'demo-app:dev.9fc74dd72d2b88bea5253c04240b21a54841f08d9918046ed55a06b5' },
  app_name: 'streaming-test',
  instance_id: 'local-streaming-cli',
  refresh_interval: 2,
  metrics_interval: 2,
  retry_limit: 2,
  experimental_mode: { type: 'streaming' },
  timeout: 5,
  log_level: Logger::DEBUG
)

feature_name = "example-flag"
unleash_context = Unleash::Context.new
unleash_context.user_id = 123

puts "Waiting for client to initialize..."
sleep 2

100.times do
  if @unleash.is_enabled?(feature_name, unleash_context)
    puts "> #{feature_name} is enabled"
  else
    puts "> #{feature_name} is not enabled"
  end
  sleep 1
  puts "---"
  puts ""
  puts ""
end
feature_name = "foobar"
if @unleash.is_enabled?(feature_name, unleash_context, true)
  puts "> #{feature_name} is enabled"
else
  puts "> #{feature_name} is not enabled"
end

puts "> shutting down client..."

@unleash.shutdown

puts ">> END streaming.rb"
