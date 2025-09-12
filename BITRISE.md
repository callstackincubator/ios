# Rock iOS Bitrise Step

This Bitrise step enables remote building of iOS applications using [Rock](https://rockjs.dev). It supports both simulator and device builds, with automatic artifact caching and code signing capabilities.

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
    - CERTIFICATE_BASE64: ''
    - CERTIFICATE_PASSWORD: ''
    - PROVISIONING_PROFILE_BASE64: ''
    - PROVISIONING_PROFILE_NAME: ''
    - KEYCHAIN_PASSWORD: ''
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
        - CERTIFICATE_BASE64: "$CERTIFICATE_BASE64"
        - CERTIFICATE_PASSWORD: "$CERTIFICATE_PASSWORD"
        - PROVISIONING_PROFILE_BASE64: "$PROVISIONING_PROFILE_BASE64"
        - PROVISIONING_PROFILE_NAME: "$PROVISIONING_PROFILE_NAME"
        - KEYCHAIN_PASSWORD: "$KEYCHAIN_PASSWORD"
```

## Bitrise Inputs

| Input                         | Description                                                                     | Required | Default     |
| ----------------------------- | ------------------------------------------------------------------------------- | -------- | ----------- |
| `WORKING_DIRECTORY`           | Working directory for the build command                                         | No       | `.`         |
| `DESTINATION`                 | Build destination: "simulator" or "device"                                      | Yes      | `simulator` |
| `SCHEME`                      | Xcode scheme                                                                    | Yes      | -           |
| `CONFIGURATION`               | Xcode configuration                                                             | Yes      | -           |
| `RE_SIGN`                     | Re-sign the app bundle with new JS bundle                                       | No       | `false`     |
| `AD_HOC`                      | Upload the IPA for ad-hoc distribution to easily install on provisioned devices | No       | `false`     |
| `CERTIFICATE_BASE64`          | Base64 encoded P12 file for device builds                                       | No       | -           |
| `CERTIFICATE_PASSWORD`        | Password for the P12 file                                                       | No       | -           |
| `PROVISIONING_PROFILE_BASE64` | Base64 encoded provisioning profile                                             | No       | -           |
| `PROVISIONING_PROFILE_NAME`   | Name of the provisioning profile                                                | No       | -           |
| `KEYCHAIN_PASSWORD`           | Password for temporary keychain                                                 | No       | -           |
| `ROCK_BUILD_EXTRA_PARAMS`     | Extra parameters for rock build:ios                                             | No       | -           |

## Bitrise Outputs

| Output         | Description               |
| -------------- | ------------------------- |
| `ARTIFACT_URL` | URL of the build artifact |
| `ARTIFACT_ID`  | ID of the build artifact  |

## License

MIT
