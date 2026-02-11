# Rock iOS GitHub Action

This GitHub Action enables remote building of iOS applications using [Rock](https://rockjs.dev). It supports both simulator and device builds, with automatic artifact caching and code signing capabilities.

## Features

- Build iOS apps for simulator or device
- Automatic artifact caching to speed up builds
- Code signing support for device builds
- Support for additional provisioning profiles (extensions, notifications, etc.)
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
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Build iOS
        uses: callstackincubator/ios@v3 # replace with latest commit hash
        with:
          destination: 'simulator' # or 'device'
          scheme: 'YourScheme'
          configuration: 'Debug'
          github-token: ${{ secrets.GITHUB_TOKEN }}
          # For device builds, add these (for certificate and provisioning profile - either file OR base64):
          # certificate-file: './certs/distribution.p12'
          # certificate-base64: ${{ secrets.CERTIFICATE_BASE64 }}
          # certificate-password: ${{ secrets.CERTIFICATE_PASSWORD }} # Optional - only needed if P12 has a password
          # keychain-password: ${{ secrets.KEYCHAIN_PASSWORD }} # Optional - defaults to auto-generated password
          # re-sign: true
          # ad-hoc: true
          # For apps that require provisioning profiles:
          # provisioning-profiles: |
          #   [
          #     {
          #       "name": "NewApp_AdHoc",
          #       "file": "./profiles/new-app-profile.mobileprovision"
          #     },
          #     {
          #       "name": "ShareExtension",
          #       "file": "./profiles/share-extension.mobileprovision"
          #     },
          #     {
          #       "name": "NotificationExtension",
          #       "base64": "${{ secrets.NOTIFICATION_PROFILE_BASE64 }}"
          #     }
          #   ]
```

## Inputs

| Input                         | Description                                                                                                                       | Required | Default     |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | -------- | ----------- |
| `github-token`                | GitHub Token                                                                                                                      | Yes      | -           |
| `working-directory`           | Working directory for the build command                                                                                           | No       | `.`         |
| `destination`                 | Build destination: "simulator" or "device"                                                                                        | Yes      | `simulator` |
| `scheme`                      | Xcode scheme                                                                                                                      | Yes      | -           |
| `configuration`               | Xcode configuration                                                                                                               | Yes      | -           |
| `re-sign`                     | Re-sign the app bundle with new JS bundle                                                                                         | No       | `false`     |
| `ad-hoc`                      | Upload the IPA for ad-hoc distribution to easily install on provisioned devices                                                   | No       | `false`     |
| `certificate-base64`          | Base64 encoded P12 file for device builds                                                                                         | No       | -           |
| `certificate-file`            | P12 file for device builds                                                                                                        | No       | -           |
| `certificate-password`        | Password for the P12 file (optional - only needed if certificate has a password)                                                  | No       | -           |
| `provisioning-profile-base64` | Base64 encoded provisioning profile                                                                                               | No       | -           |
| `provisioning-profile-file`   | Provisioning profile file                                                                                                         | No       | -           |
| `provisioning-profile-name`   | Name of the provisioning profile                                                                                                  | No       | -           |
| `provisioning-profiles`       | JSON array of provisioning profiles. Supports passing PP as both file and base64 string. Supported keys: `name`, `file`, `base64` | No       | -           |
| `keychain-password`           | Password for temporary keychain (optional - defaults to auto-generated password)                                                  | No       | -           |
| `rock-build-extra-params`     | Extra parameters for rock build:ios                                                                                               | No       | -           |
| `comment-bot`                 | Whether to comment PR with build link                                                                                             | No       | `true`      |
| `custom-identifier`           | Custom identifier used in artifact naming for re-sign and ad-hoc flows to distinguish builds with the same native fingerprint     | No       | -           |

## Artifact Naming

The action uses two distinct naming strategies for uploads:

### ZIP Artifacts (native build caching)

ZIP artifacts store the native build for reuse. The naming depends on the flow:

- **Ad-hoc flow** (`ad-hoc: true`): ZIP name uses **fingerprint only** — `rock-ios-{dest}-{config}-{fingerprint}`. One ZIP per fingerprint, shared across all builds with the same native code. Skipped if already uploaded.
- **Non-ad-hoc re-sign flow** (e.g. `pull_request` with `re-sign: true`): ZIP name includes an **identifier** — `rock-ios-{dest}-{config}-{identifier}-{fingerprint}`. Used as the distribution mechanism without adhoc builds.
- **Regular builds** (no `re-sign`): ZIP name uses **fingerprint only** `rock-ios-{dest}-{config}-{fingerprint}`

### Ad-Hoc Artifacts (distribution to testers)

When `ad-hoc: true`, distribution files (IPA + `index.html` + `manifest.plist`) are uploaded under a name that **always includes an identifier**: `rock-ios-{dest}-{config}-{identifier}-{fingerprint}`. This ensures every uploaded adhoc build can point to unique distribution URL based on `{identifier}`, even when multiple builds share the same native fingerprint.

### Identifier Priority

The identifier distinguishes builds that share the same native fingerprint (e.g., concurrent builds from different branches).
It is resolved in this order:
1. `custom-identifier` input — explicit value provided by the caller (e.g., commit SHA of the head of the PR branch)
2. PR number — automatically extracted from `pull_request` events
3. Short commit SHA — 7-character fallback for push events and dispatches

> **Note:** The identifier becomes part of artifact names and S3 paths. Allowed characters: `a-z`, `A-Z`, `0-9`, `-`, `.`, `_`. Commas are used internally as trait delimiters and converted to hyphens (e.g., `device,Release,42` → `device-Release-42`), so they must not appear in the identifier. Spaces, slashes, and shell metacharacters are also not allowed.

## Outputs

| Output         | Description               |
| -------------- | ------------------------- |
| `artifact-url` | URL of the build artifact |
| `artifact-id`  | ID of the build artifact  |

## Prerequisites

- macOS runner
- Rock CLI installed in your project
- For device builds:
  - Valid Apple Developer certificate
  - Valid provisioning profile
  - Proper code signing setup

## License

MIT
