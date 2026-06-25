# Rock iOS Bitrise Step

This Bitrise step enables remote building of iOS applications using [Rock](https://rockjs.dev). It supports both simulator and device builds, with automatic artifact caching. Code signing should be configured separately in your workflow before using this step.

> [!NOTE]
> **Code Signing Required**: This step assumes that iOS code signing is already configured in your workflow before using this step. For device builds and re-signing, certificates and provisioning profiles must be available in the keychain. See the [Bitrise iOS Code Signing documentation](https://docs.bitrise.io/en/bitrise-ci/code-signing/ios-code-signing/ios-code-signing.html) for setup instructions.

## Usage

```yaml
---
format_version: '23'
default_step_lib_source: https://github.com/bitrise-io/bitrise-steplib.git
project_type: react-native
meta:
  bitrise.io:
    stack: osx-xcode-16.4.x
    machine_type_id: g2.mac.large
workflows:
  rock-remote-build-ios:
    description: 'Rock Remote Build - iOS'
    envs:
    - WORKING_DIRECTORY: "$BITRISE_SOURCE_DIR"
    - DESTINATION: simulator
    - SCHEME: RockRemoteBuildTest
    - CONFIGURATION: Release
    - RE_SIGN: 'false'
    - AD_HOC: 'false'
    - ROCK_BUILD_EXTRA_PARAMS: ''
    - SIGNING_IDENTITY: ''
    steps:
    - activate-ssh-key@4: {}
    - git-clone@8: {}
    - npm@1:
        title: npm install
        inputs:
        - workdir: "$WORKING_DIRECTORY"
        - command: install
    - git::https://github.com/callstackincubator/ios@main:
        title: Rock Remote Build - iOS
        inputs:
        - WORKING_DIRECTORY: "$WORKING_DIRECTORY"
        - DESTINATION: "$DESTINATION"
        - SCHEME: "$SCHEME"
        - CONFIGURATION: "$CONFIGURATION"
        - RE_SIGN: "$RE_SIGN"
        - AD_HOC: "$AD_HOC"
        - ROCK_BUILD_EXTRA_PARAMS: "$ROCK_BUILD_EXTRA_PARAMS"
        - SIGNING_IDENTITY: "$SIGNING_IDENTITY"
```

## Bitrise Inputs

| Input                         | Description                                                                     | Required | Default     |
| ----------------------------- | ------------------------------------------------------------------------------- | -------- | ----------- |
| `WORKING_DIRECTORY`           | Working directory for the build command                                         | No       | `.`         |
| `DESTINATION`                 | Build destination: "simulator" or "device"                                      | Yes      | `simulator` |
| `SCHEME`                      | Xcode scheme                                                                    | Yes      | -           |
| `CONFIGURATION`               | Xcode configuration                                                             | Yes      | -           |
| `RE_SIGN`                     | Re-sign the app bundle with new JS bundle. Requires certificates in keychain    | No       | `false`     |
| `AD_HOC`                      | Upload the IPA for ad-hoc distribution to easily install on provisioned devices | No       | `false`     |
| `SIGNING_IDENTITY`            | Code signing identity for re-signing. Auto-detects if not provided              | No       | -           |
| `ROCK_BUILD_EXTRA_PARAMS`     | Extra parameters for rock build:ios                                             | No       | -           |

## Bitrise Outputs

| Output         | Description               |
| -------------- | ------------------------- |
| `ARTIFACT_URL` | URL of the build artifact |
| `ARTIFACT_ID`  | ID of the build artifact  |

## License

MIT
