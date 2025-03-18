# RNEF iOS GitHub Action

This GitHub Action enables remote building of iOS applications using RNEF (React Native Enterprise Framework). It supports both simulator and device builds, with automatic artifact caching and code signing capabilities.

## Features

- Build iOS apps for simulator or device
- Automatic artifact caching to speed up builds
- Code signing support for device builds
- Re-signing capability for PR builds
- Native fingerprint-based caching
- Configurable build parameters

## Usage

```yaml
name: iOS Build
on:
  push:
    branches: [main]
  pull_request:
    branches: ['**']

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build iOS
        uses: callstackincubator/ios@v1
        with:
          destination: 'simulator' # or 'device'
          scheme: 'YourScheme'
          configuration: 'Debug'
          github-token: ${{ secrets.GITHUB_TOKEN }}
          # For device builds, add these:
          # certificate-base64: ${{ secrets.CERTIFICATE_BASE64 }}
          # certificate-password: ${{ secrets.CERTIFICATE_PASSWORD }}
          # provisioning-profile-base64: ${{ secrets.PROVISIONING_PROFILE_BASE64 }}
          # provisioning-profile-name: 'YourProfileName'
          # keychain-password: ${{ secrets.KEYCHAIN_PASSWORD }}
```

## Inputs

| Input                         | Description                                | Required | Default               |
| ----------------------------- | ------------------------------------------ | -------- | --------------------- |
| `github-token`                | GitHub Token                               | Yes      | -                     |
| `working-directory`           | Working directory for the build command    | No       | `.`                   |
| `destination`                 | Build destination: "simulator" or "device" | Yes      | `simulator`           |
| `scheme`                      | Xcode scheme                               | Yes      | -                     |
| `configuration`               | Xcode configuration                        | Yes      | -                     |
| `re-sign`                     | Re-sign the app bundle with new JS bundle  | No       | `false`               |
| `certificate-base64`          | Base64 encoded P12 file for device builds  | No       | -                     |
| `certificate-password`        | Password for the P12 file                  | No       | -                     |
| `provisioning-profile-base64` | Base64 encoded provisioning profile        | No       | -                     |
| `provisioning-profile-name`   | Name of the provisioning profile           | No       | -                     |
| `keychain-password`           | Password for temporary keychain            | No       | -                     |
| `rnef-build-extra-params`     | Extra parameters for rnef build:ios        | No       | -                     |
| `comment-bot`                 | Whether to comment PR with build link      | No       | `true`                |

## Outputs

| Output         | Description               |
| -------------- | ------------------------- |
| `artifact-url` | URL of the build artifact |
| `artifact-id`  | ID of the build artifact  |

## Prerequisites

- macOS runner
- RNEF CLI installed in your project
- For device builds:
  - Valid Apple Developer certificate
  - Valid provisioning profile
  - Proper code signing setup

## License

MIT
