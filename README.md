# Unleash::Client

![Build Status](https://github.com/Unleash/unleash-ruby-sdk/actions/workflows/pull_request.yml/badge.svg?branch=main)
[![Coverage Status](https://coveralls.io/repos/github/Unleash/unleash-ruby-sdk/badge.svg?branch=main)](https://coveralls.io/github/Unleash/unleash-ruby-sdk?branch=main)
[![Gem Version](https://badge.fury.io/rb/unleash.svg)](https://badge.fury.io/rb/unleash)

Unleash is a private, secure, and scalable [feature management platform](https://www.getunleash.io/) built to reduce the risk of releasing new features and accelerate software development. This Ruby SDK is designed to help you integrate with Unleash and evaluate feature flags inside your application.

You can use this client with [Unleash Enterprise](https://www.getunleash.io/pricing?utm_source=readme&utm_medium={{language}}) or [Unleash Open Source](https://github.com/Unleash/unleash).

>  **Migrating to v6**
>
> If you use [custom strategies](#custom-strategies) or override built-in ones, read the complete [migration guide](./v6_MIGRATION_GUIDE.md) before upgrading to v6.


## Supported Ruby interpreters

- MRI 3.4
- MRI 3.3
- MRI 3.2
- MRI 3.1
- MRI 3.0
- MRI 2.7
- jruby 9.4

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'unleash', '~> 6.3.0'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install unleash

## Configuration

It is **required** to configure:

- `app_name` with the name of the running application
- `url` of your Unleash server
- `custom_http_headers` with `{'Authorization': '<YOUR_API_TOKEN>'}` when using Unleash v4+

It is **highly recommended** to configure:

- `instance_id` parameter with a unique identifier for the running instance

```ruby
Unleash.configure do |config|
  config.app_name            = 'my_ruby_app'
  config.url                 = '<YOUR_UNLEASH_URL>/api'
  config.custom_http_headers = {'Authorization': '<YOUR_API_TOKEN>'}
end
```

or instantiate the client with the valid configuration:

```ruby
UNLEASH = Unleash::Client.new(url: '<YOUR_UNLEASH_URL>/api', app_name: 'my_ruby_app', custom_http_headers: {'Authorization': '<YOUR_API_TOKEN>'})
```

## Dynamic custom HTTP headers

If you need custom HTTP headers that change during the lifetime of the client, you can pass `custom_http_headers` as a `Proc`.

```ruby
Unleash.configure do |config|
  config.app_name            = 'my_ruby_app'
  config.url                 = '<YOUR_UNLEASH_URL>/api'
  config.custom_http_headers =  proc do
    {
      'Authorization': '<YOUR_API_TOKEN>',
      'X-Client-Request-Time': Time.now.iso8601
    }
  end
end
```

#### List of arguments

| Argument              | Description                                                                                                                                                                                                                                                                                                                   | Required? | Type                              | Default value                                  |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | --------------------------------- | ---------------------------------------------- |
| `url`                 | Unleash server URL.                                                                                                                                                                                                                                                                                                           | Y         | String                            | N/A                                            |
| `app_name`            | Name of your program.                                                                                                                                                                                                                                                                                                         | Y         | String                            | N/A                                            |
| `instance_id`         | Identifier for the running instance of your program—set this to be able trace where metrics are being collected from.                                                                                                                                                                  | N         | String                            | random UUID                                    |
| `environment`         | Unleash context option, for example, `prod` or `dev`. Not yet in use. **Not** the same as the SDK's [Unleash environment](https://docs.getunleash.io/reference/environments).                                                                                                                                         | N         | String                            | `default`                                      |
| `project_name`        | Name of the project to retrieve feature flags from. If not set, all feature flags will be retrieved.                                                                                                                                                                                                                               | N         | String                            | nil                                            |
| `refresh_interval`    | How often the Unleash client should check with the server for configuration changes.                                                                                                                                                                                                                                          | N         | Integer                           | 15                                             |
| `metrics_interval`    | How often the Unleash client should send metrics to server.                                                                                                                                                                                                                                                                   | N         | Integer                           | 60                                             |
| `disable_client`      | Disables all communication with the Unleash server, effectively taking it _offline_. If set, `is_enabled?` always answer with the `default_value` and configuration validation is skipped. Will also forcefully set `disable_metrics` to `true`. Defeats the entire purpose of using Unleash, except when running tests. | N         | Boolean                           | `false`                                        |
| `disable_metrics`     | Disables sending metrics to Unleash server. If the `disable_client` option is set to `true`, then this option will also be set to `true`, regardless of the value provided.                                                                                                                                                   | N         | Boolean                           | `false`                                        |
| `custom_http_headers` | Custom headers to send to Unleash. As of Unleash v4.0.0, the `Authorization` header is required. For example: `{'Authorization': '<YOUR_API_TOKEN>'}`.                                                                                                                                                                              | N         | Hash/Proc                         | {}                                             |
| `timeout`             | How long to wait for the connection to be established or wait in reading state (open_timeout/read_timeout)                                                                                                                                                                                                                    | N         | Integer                           | 30                                             |
| `retry_limit`         | How many consecutive failures in connecting to the Unleash server are allowed before giving up. The default is to retry indefinitely.                                                                                                                                                                                         | N         | Float::INFINITY                   | 5                                              |
| `backup_file`         | Filename to store the last known state from the Unleash server. It is best to not change this from the default.                                                                                                                                                                                                                     | N         | String                            | `Dir.tmpdir + "/unleash-#{app_name}-repo.json` |
| `logger`              | Specify a custom `Logger` class to handle logs for the Unleash client.                                                                                                                                                                                                                                                        | N         | Class                             | `Logger.new(STDOUT)`                           |
| `log_level`           | Change the log level for the `Logger` class. Constant from `Logger::Severity`.                                                                                                                                                                                                                                                | N         | Constant                          | `Logger::WARN`                                 |
| `bootstrap_config`    | Bootstrap config for loading data on startup—useful for loading large states on startup without (or before) hitting the network.                                                                                                                                                                               | N         | Unleash::Bootstrap::Configuration | `nil`                                          |
| `strategies`          | Strategies manager that holds all strategies and allows to add custom strategies.                                                                                                                                                                                                                                              | N         | Unleash::Strategies               | `Unleash::Strategies.new`                      |

For a more in-depth look, please see `lib/unleash/configuration.rb`.

| Environment Variable     | Description                      |
| ------------------------ | -------------------------------- |
| `UNLEASH_BOOTSTRAP_FILE` | File to read bootstrap data from |
| `UNLEASH_BOOTSTRAP_URL`  | URL to read bootstrap data from  |

## Usage in a plain Ruby application

```ruby
require 'unleash'
require 'unleash/context'

@unleash = Unleash::Client.new(app_name: 'my_ruby_app', url: '<YOUR_UNLEASH_URL>/api', custom_http_headers: { 'Authorization': '<YOUR_API_TOKEN>' })

feature_name = "AwesomeFeature"
unleash_context = Unleash::Context.new
unleash_context.user_id = 123

if @unleash.is_enabled?(feature_name, unleash_context)
  puts " #{feature_name} is enabled according to unleash"
else
  puts " #{feature_name} is disabled according to unleash"
end

if @unleash.is_disabled?(feature_name, unleash_context)
  puts " #{feature_name} is disabled according to unleash"
else
  puts " #{feature_name} is enabled according to unleash"
end
```

## Usage in a Rails application

### 1. Add Initializer

The initializer setup varies depending on whether you’re using a standard setup, Puma in clustered mode, Phusion Passenger, or Sidekiq.

#### 1.a Initializer for standard Rails applications

Put in `config/initializers/unleash.rb`:

```ruby
Unleash.configure do |config|
  config.app_name = Rails.application.class.module_parent_name
  config.url      = '<YOUR_UNLEASH_URL>'
  # config.instance_id = "#{Socket.gethostname}"
  config.logger   = Rails.logger
  config.custom_http_headers = {'Authorization': '<YOUR_API_TOKEN>'}
end

UNLEASH = Unleash::Client.new

# Or if preferred:
# Rails.configuration.unleash = Unleash::Client.new
```

For `config.instance_id` use a string with a unique identification for the running instance. For example, it could be the hostname if you only run one App per host, or the docker container ID, if you are running in Docker.
If not set, the client will generate a unique UUID for each execution.

To have it available in the `rails console` command as well, also add to the file above:

```ruby
Rails.application.console do
  UNLEASH = Unleash::Client.new
  # or
  # Rails.configuration.unleash = Unleash::Client.new
end
```

#### 1.b Add Initializer if using [Puma in clustered mode](https://github.com/puma/puma#clustered-mode)

That is, multiple workers configured in `puma.rb`:

```ruby
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
```

##### with `preload_app!`

Then you may keep the client configuration still in `config/initializers/unleash.rb`:

```ruby
Unleash.configure do |config|
  config.app_name    = Rails.application.class.parent.to_s
  config.url                 = '<YOUR_UNLEASH_URL>/api'
  config.custom_http_headers = {'Authorization': '<YOUR_API_TOKEN>'}
end
```

But you must ensure that the Unleash client is instantiated only after the process is forked.
This is done by creating the client inside the `on_worker_boot` code block in `puma.rb` as below:

```ruby
#...
preload_app!
#...

on_worker_boot do
  # ...

  ::UNLEASH = Unleash::Client.new
end

on_worker_shutdown do
  ::UNLEASH.shutdown
end
```

##### without `preload_app!`

By not using `preload_app!`:

- The `Rails` constant will **not** be available.
- Phased restarts will be possible.

You need to ensure that in `puma.rb`:

- The Unleash SDK is loaded with `require 'unleash'` explicitly, as it will not be pre-loaded.
- All parameters are set explicitly in the `on_worker_boot` block, as `config/initializers/unleash.rb` is not read.
- There are no references to `Rails` constant, as that is not yet available.

Example for `puma.rb`:

```ruby
require 'unleash'

#...
# no preload_app!

on_worker_boot do
  # ...

  ::UNLEASH = Unleash::Client.new(
    app_name: 'my_rails_app',
    url: '<YOUR_UNLEASH_URL>/api',
    custom_http_headers: {'Authorization': '<YOUR_API_TOKEN>'},
  )
end

on_worker_shutdown do
  ::UNLEASH.shutdown
end
```

Note that we also added shutdown hooks in `on_worker_shutdown`, to ensure a clean shutdown.

#### 1.c Add Initializer if using [Phusion Passenger](https://github.com/phusion/passenger)

The Unleash client needs to be configured and instantiated inside the `PhusionPassenger.on_event(:starting_worker_process)` code block due to [smart spawning](https://www.phusionpassenger.com/library/indepth/ruby/spawn_methods/#smart-spawning-caveats):

The initializer in `config/initializers/unleash.rb` should look like:

```ruby
PhusionPassenger.on_event(:starting_worker_process) do |forked|
  if forked
    Unleash.configure do |config|
      config.app_name    = Rails.application.class.parent.to_s
      # config.instance_id = "#{Socket.gethostname}"
      config.logger      = Rails.logger
      config.url                 = '<YOUR_UNLEASH_URL>/api'
      config.custom_http_headers = {'Authorization': '<YOUR_API_TOKEN>'}
    end

    UNLEASH = Unleash::Client.new
  end
end
```

#### 1.d Add Initializer hooks when using within [Sidekiq](https://github.com/mperham/sidekiq)

Note that in this case, we require that the code block for `Unleash.configure` is set beforehand.
For example in `config/initializers/unleash.rb`.

```ruby
Sidekiq.configure_server do |config|
  config.on(:startup) do
    UNLEASH = Unleash::Client.new
  end

  config.on(:shutdown) do
    UNLEASH.shutdown
  end
end
```

### 2. Set Unleash::Context

Add the following method and callback in the application controller to have `@unleash_context` set for all requests:

Add in `app/controllers/application_controller.rb`:

```ruby
  before_action :set_unleash_context

  private
  def set_unleash_context
    @unleash_context = Unleash::Context.new(
      session_id: session.id,
      remote_address: request.remote_ip,
      user_id: session[:user_id]
    )
  end
```

Alternatively, you can add this method only to the controllers that use Unleash.

### 3. Sample usage

Then wherever in your application that you need a feature toggle, you can use:

```ruby
if UNLEASH.is_enabled? "AwesomeFeature", @unleash_context
  puts "AwesomeFeature is enabled"
end
```

or if client is set in `Rails.configuration.unleash`:

```ruby
if Rails.configuration.unleash.is_enabled? "AwesomeFeature", @unleash_context
  puts "AwesomeFeature is enabled"
end
```

If you don't want to check a feature is disabled with `unless`, you can also use `is_disabled?`:

```ruby
# so instead of:
unless UNLEASH.is_enabled? "AwesomeFeature", @unleash_context
  puts "AwesomeFeature is disabled"
end

# it might be more intelligible:
if UNLEASH.is_disabled? "AwesomeFeature", @unleash_context
  puts "AwesomeFeature is disabled"
end
```

If the feature is not found in the server, it will by default return false.
However, you can override that by setting the default return value to `true`:

```ruby
if UNLEASH.is_enabled? "AwesomeFeature", @unleash_context, true
  puts "AwesomeFeature is enabled by default"
end
# or
if UNLEASH.is_disabled? "AwesomeFeature", @unleash_context, true
  puts "AwesomeFeature is disabled by default"
end
```

Another possibility is to send a block, [Lambda](https://ruby-doc.org/core-3.0.1/Kernel.html#method-i-lambda) or [Proc](https://ruby-doc.org/core-3.0.1/Proc.html#method-i-yield)
to evaluate the default value:

```ruby
net_check_proc = proc do |feature_name, context|
  context.remote_address.starts_with?("10.0.0.")
end

if UNLEASH.is_enabled?("AwesomeFeature", @unleash_context, &net_check_proc)
  puts "AwesomeFeature is enabled by default if you are in the 10.0.0.* network."
end
```

or

```ruby
awesomeness = 10
@unleash_context.properties[:coolness] = 10

if UNLEASH.is_enabled?("AwesomeFeature", @unleash_context) { |feat, ctx| awesomeness >= 6 && ctx.properties[:coolness] >= 8 }
  puts "AwesomeFeature is enabled by default if both the user has a high enough coolness and the application has a high enough awesomeness"
end
```

Note:

- The block/lambda/proc can use the feature name and context as arguments.
- The client will evaluate the fallback function once per call of `is_enabled()`.
  Please keep this in mind when creating your fallback function.
- The returned value of the block should be a boolean.
  However, the client will coerce the result to a boolean via `!!`.
- If both a `default_value` and `fallback_function` are supplied,
  the client will define the default value by `OR`ing the default value and the output of the fallback function.

Alternatively by using `if_enabled` (or `if_disabled`) you can send a code block to be executed as a parameter:

```ruby
UNLEASH.if_enabled "AwesomeFeature", @unleash_context, true do
  puts "AwesomeFeature is enabled by default"
end
```

Note: `if_enabled` (and `if_disabled`) only support `default_value`, but not `fallback_function`.

#### Variations

If no flag is found in the server, use the fallback variant.

```ruby
fallback_variant = Unleash::Variant.new(name: 'default', enabled: true, payload: {"color" => "blue"})
variant = UNLEASH.get_variant "ColorVariants", @unleash_context, fallback_variant

puts "variant color is: #{variant.payload.fetch('color')}"
```

## Bootstrapping

Bootstrap configuration allows the client to be initialized with a predefined set of toggle states.
Bootstrapping can be configured by providing a bootstrap configuration when initializing the client.

```ruby
@unleash = Unleash::Client.new(
    url: '<YOUR_UNLEASH_URL>/api',
    app_name: 'my_ruby_app',
    custom_http_headers: { 'Authorization': '<YOUR_API_TOKEN>' },
    bootstrap_config: Unleash::Bootstrap::Configuration.new({
        url: "<YOUR_UNLEASH_URL>/api/client/features",
        url_headers: {'Authorization': '<YOUR_API_TOKEN>'}
    })
)
```

The `Bootstrap::Configuration` initializer takes a hash with one of the following options specified:

- `file_path` - An absolute or relative path to a file containing a JSON string of the response body from the Unleash server. This can also be set through the `UNLEASH_BOOTSTRAP_FILE` environment variable.
- `url` - A url pointing to an Unleash server's features endpoint, the code sample above is illustrative. This can also be set through the `UNLEASH_BOOTSTRAP_URL` environment variable.
- `url_headers` - Headers for the GET HTTP request to the `url` above. Only used if the `url` parameter is also set. If this option isn't set then the bootstrapper will use the same url headers as the Unleash client.
- `data` - A raw JSON string as returned by the Unleash server.
- `block` - A lambda containing custom logic if you need it, an example is provided below.

You should only specify one type of bootstrapping since only one will be invoked and the others will be ignored.
The order of preference is as follows:

- Select a data bootstrapper if it exists.
- If no data bootstrapper exists, select the block bootstrapper.
- If no block bootstrapper exists, select the file bootstrapper from either parameters or the specified environment variable.
- If no file bootstrapper exists, then check for a URL bootstrapper from either the parameters or the specified environment variable.

Example usage:

First, save the toggles locally:

```shell
curl -H 'Authorization: <YOUR_API_TOKEN>' -XGET '<YOUR_UNLEASH_URL>/api' > ./default-toggles.json
```

Then use them on startup:

```ruby

custom_boostrapper = lambda {
  File.read('./default-toggles.json')
}

@unleash = Unleash::Client.new(
    app_name: 'my_ruby_app',
    url: '<YOUR_UNLEASH_URL>/api',
    custom_http_headers: { 'Authorization': '<YOUR_API_TOKEN>' },
    bootstrap_config: Unleash::Bootstrap::Configuration.new({
        block: custom_boostrapper
    })
)
```

This example could be easily achieved with a file bootstrapper, this is just to illustrate the usage of custom bootstrapping.
Be aware that the client initializer will block until bootstrapping is complete.

#### Client methods

| Method name    | Description                                                                                                                                                                                     | Return type        |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| `is_enabled?`  | Checks if a feature toggle is enabled or not                                                                                                                                                | Boolean            |
| `enabled?`     | A more idiomatic Ruby alias for the `is_enabled?` method                                                                                                                                     | Boolean            |
| `if_enabled`   | Runs a code block, if a feature is enabled                                                                                                                                                      | `yield`            |
| `is_disabled?` | Checks if feature toggle is enabled or not                                                                                                                                                | Boolean            |
| `disabled?`    | A more idiomatic Ruby alias for the `is_disabled?` method                                                                                                                                    | Boolean            |
| `if_disabled`  | Runs a code block, if a feature is disabled                                                                                                                                                     | `yield`            |
| `get_variant`  | Gets variant for a given feature                                                                                                                                                                 | `Unleash::Variant` |
| `shutdown`     | Saves metrics to disk, flushes metrics to server, and then kills `ToggleFetcher` and `MetricsReporter` threads—a safe shutdown, not generally needed in long-running applications, like web applications | nil                |
| `shutdown!`    | Kills `ToggleFetcher` and `MetricsReporter` threads immediately                                                                                                                                     | nil                |

For the full method signatures, see [client.rb](lib/unleash/client.rb).

## Local test client

```
# cli unleash client:
bundle exec bin/unleash-client --help

# or a simple sample implementation (with values hardcoded):
bundle exec examples/simple.rb
```

## Available strategies

This client comes with all the required strategies out of the box:

- ApplicationHostnameStrategy
- DefaultStrategy
- FlexibleRolloutStrategy
- GradualRolloutRandomStrategy
- GradualRolloutSessionIdStrategy
- GradualRolloutUserIdStrategy
- RemoteAddressStrategy
- UnknownStrategy
- UserWithIdStrategy

## Custom strategies

You can add [custom activation strategies](https://docs.getunleash.io/advanced/custom_activation_strategy) using configuration.
In order for the strategy to work correctly it should support two methods `name` and `is_enabled?`.

```ruby
class MyCustomStrategy
  def name
    'myCustomStrategy'
  end

  def is_enabled?(params = {}, context = nil)
    true
  end
end

Unleash.configure do |config|
  config.strategies.add(MyCustomStrategy.new)
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `bundle exec rake spec` to run the tests.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

This SDK is also built against the Unleash Client Specification tests.
To run the Ruby SDK against this test suite, you'll need to have a copy on your machine, you can clone the repository directly using:

`git clone --branch v$(ruby echo_client_spec_version.rb) https://github.com/Unleash/client-specification.git`

After doing this, `bundle exec rake spec` will also run the client specification tests.

To install this gem onto your local machine, run `bundle exec rake install`.

## Releasing

To release a new version, follow these steps:

1. Update version number:
     - Increment the version number in the `./lib/unleash/version.rb` file according to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) guidelines.
2. Update documentation:
     - If the update includes a major or minor version change, update the [Installation section](#installation) in [README.md](README.md).
     - Update [CHANGELOG.md](CHANGELOG.md) following the format on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
3. Commit changes:
     - Commit the changes with a message like: `chore: bump version to x.y.z.`
4. Release the gem:
   	- On the `main` branch, run `bundle exec rake release` to create a git tag for the new version, push commits and tags to origin, and publish `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/unleash/unleash-ruby-sdk.

Be sure to run both `bundle exec rspec` and `bundle exec rubocop` in your branch before creating a pull request.

Please include tests with any pull requests, to avoid regressions.

Check out our guide for more information on how to build and scale [feature flag systems](https://docs.getunleash.io/topics/feature-flags/feature-flag-best-practices).
