![Build](https://github.com/Unleash/client-specification/workflows/Build/badge.svg)

# Unleash Client Specifications
Implementing a Unleash client for a specific platform can be a challenge in it's own. And we want the clients to follow specific platform and language conventions, but at the same time we want the clients to adhere to the unleash contract, and give predictable results across platforms.

This project tries to define the expected results of certain predefined set of feature toggles, using the  [built-in activation strategies](https://docs.getunleash.io/user_guide/activation_strategy) and with a given [unleash context](https://docs.getunleash.io/user_guide/unleash_context).


### Test structure
All the tests are located in the [/specifications](specifications) folder.

There is an entry point for all the tests, which will include a list of all the defined specification test cases, [/specifications/index.json](https://github.com/Unleash/client-specification/blob/main/specifications/index.json). Clients should parse this entry-point in order to discover all specifications to run.

```json
[
  "01-simple-examples.json",
  "02-user-with-id-strategy.json",
  "03-gradual-rollout-user-id-strategy.json",
  "04-gradual-rollout-session-id-strategy.json",
  "05-gradual-rollout-random-strategy.json",
  "06-remote-address-strategy.json",
  "07-multiple-strategies.json",
  "08-variants.json",
  "09-strategy-constraints.json",
  "10-flexible-rollout-strategy.json",
  "11-strategy-constraints-edge-cases.json",
  "12-custom-stickiness.json",
  "13-constraint-operators.json",
  "14-constraint-semver-operators.json"
  "15-global-constraints.json"
]
```

A Test Specifications will have the following shape:

```json
{
    "name": "Example Test Case",
    "state": {
        "version": 1,
        "features": []
    },
    "tests": [
        {
            "description": "Unknown toggle should be disabled",
            "context": {},
            "toggleName": "Unknown.Toggle",
            "expectedResult": false
        }
    ],
    "variantTests": [
        {
            "description": "Feature with variants",
            "context": {
                "userId": "1234"
            },
            "toggleName": "Feature.Variants",
            "expectedResult": {
                "name": "variant",
                "payload": {
                    "type": "string",
                    "value": "value"
                },
                "enabled": true
                "feature_enabled": true
            }
        }
    ]
}
```

Fields description:

- **name** - The name of the specification
- **state** - The list of toggles coming from the unleash-server. Would be the same response as the client will see when requesting `http://unleash-api/client/features`. The state will be used for all test cases in this specification.
- **tests** - The list of `isEnabled` tests cases to run.
  - **description** - Describes what this test case is testing. Suitable to output as the error message if the test case fails.
  - **context** - The [unleash context](https://docs.getunleash.io/user_guide/unleash_context) the client should setup.
  - **toggleName** - The toggle name to send in to the `isEnabled` call in this test case.
  - **expectedResult** - The expected result of the `isEnabled` call with the given `toggleName`.
- **variantTests** - The list of `getVariant` tests cases to run.
  - **description** - Describes what this test case is testing. Suitable to output as the error message if the test case fails.
  - **context** - The [unleash context](https://docs.getunleash.io/user_guide/unleash_context) the client should setup.
  - **toggleName** - The toggle name to send in to the `isEnabled` call in this test case.
  - **expectedResult** - The expected result of the `getVariant` call with the given `toggleName`.

## Releasing
From main:
1. Run `yarn version` and write the version number.
2. Run `git checkout -b <branch_name>` and make PR
3. Wait for PR to get approved and merged
4. Push `git push origin main --tags`
