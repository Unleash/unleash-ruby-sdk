D = Steep::Diagnostic

target :lib do
  signature "*.rbs"

  # NOTE: All client-exposed methods/types should now have type signatures / rbs support
  check "lib/unleash/client.rb"
  check "lib/unleash/context.rb"
  check "lib/unleash/variant.rb"
  check "lib/unleash/scheduled_executor.rb"

  # TODO: add signatures to the rest
  # Mostly internal SDK files.
  ignore "lib/unleash/bootstrap"
  ignore "lib/unleash/strategy/*.rb"
  ignore "lib/unleash/util"

  ignore "lib/unleash/constraint.rb"
  ignore "lib/unleash/feature_toggle.rb"
  ignore "lib/unleash/metrics.rb"
  ignore "lib/unleash/metrics_reporter.rb"
  ignore "lib/unleash/toggle_fetcher.rb"
  ignore "lib/unleash/variant_definition.rb"
  ignore "lib/unleash/variant_override.rb"

  # library "pathname", "set"       # Standard libraries
  # library "strong_json"           # Gems

  # configure_code_diagnostics(D::Ruby.strict)       # `strict` diagnostics setting
  # configure_code_diagnostics(D::Ruby.lenient)      # `lenient` diagnostics setting
  configure_code_diagnostics do |hash|             # You can setup everything yourself
    hash[D::Ruby::NoMethod] = :information
    hash[D::Ruby::UnsupportedSyntax] = :information
  end
end
