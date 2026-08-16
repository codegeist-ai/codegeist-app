# Android Release APK

Runbook for maintaining the Codegeist signing identity and building a stable APK
locally when the GitHub release workflow needs independent verification or
recovery.

## Boundary

The canonical release key is generated and backed up on a trusted local machine.
An encrypted GitHub `release` environment copy lets
`.github/workflows/android-release-apk.yml` publish the current APK; the key and
passwords must never enter Git, workflow text, logs, chat, issues, or public
artifacts. The same release key must sign every later direct-install update for
Android to accept an in-place upgrade.

The APK requires Android 13 (API 33) or newer and contains `arm64-v8a` and
`x86_64` native code but no GGUF model weights. The first model load still
downloads and verifies the pinned model.

## Release Identity

- Package id: `ai.codegeist.app`
- Installed name: `Codegeist`
- Version source: `pubspec.yaml`
- APK output: `build/app/outputs/flutter-apk/app-release.apk`

Increment the `pubspec.yaml` build number for every distributed update. Android
rejects an update with a lower version code even when its signature matches.

## Create The Release Key

Generate the real release key interactively outside the checkout. `keytool`
prompts for passwords instead of placing them in shell history:

```bash
install -d -m 0700 "$HOME/.config/codegeist"
keytool -genkeypair -v \
  -keystore "$HOME/.config/codegeist/codegeist-release.jks" \
  -storetype JKS \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -alias release
chmod 0600 "$HOME/.config/codegeist/codegeist-release.jks"
```

Inspect and export the public certificate for recovery records:

```bash
keytool -list -v \
  -keystore "$HOME/.config/codegeist/codegeist-release.jks" \
  -alias release
keytool -exportcert -rfc \
  -keystore "$HOME/.config/codegeist/codegeist-release.jks" \
  -alias release \
  -file "$HOME/.config/codegeist/codegeist-release-certificate.pem"
```

Back up the keystore, both passwords, alias, certificate, and SHA-256
fingerprint in approved encrypted storage before placing the encrypted values
in GitHub or distributing the first APK. Losing the private key makes future
in-place updates impossible; exposing it requires replacing the
direct-distribution identity and reinstalling the app.

## Build Locally

Run from the repository root inside the rebuilt project devcontainer. Build only
from the intended committed source; `git status --short` must produce no output:

```bash
git status --short
git rev-parse HEAD
task verify
```

Set the non-secret path and alias, then read passwords without terminal echo or
shell-history arguments:

```bash
export ANDROID_RELEASE_KEYSTORE_PATH="$HOME/.config/codegeist/codegeist-release.jks"
export ANDROID_RELEASE_KEY_ALIAS=release
export ANDROID_RELEASE_CERT_SHA256='<recorded SHA-256 certificate fingerprint>'

read -r -s -p 'Keystore password: ' ANDROID_RELEASE_KEYSTORE_PASSWORD
printf '\n'
export ANDROID_RELEASE_KEYSTORE_PASSWORD

read -r -s -p 'Key password: ' ANDROID_RELEASE_KEY_PASSWORD
printf '\n'
export ANDROID_RELEASE_KEY_PASSWORD
```

Build and verify the universal release APK:

```bash
task apk

apk=build/app/outputs/flutter-apk/app-release.apk
test -s "$apk"
verification="$(
  "$ANDROID_SDK_ROOT/build-tools/36.0.0/apksigner" \
    verify --verbose --print-certs "$apk"
)"
printf '%s\n' "$verification"
rg -qx 'Number of signers: 1' <<< "$verification"
certificate_line="$(
  rg -m1 '^Signer #1 certificate SHA-256 digest: ' <<< "$verification"
)"
actual_fingerprint="${certificate_line##*: }"
actual_fingerprint="${actual_fingerprint//:/}"
expected_fingerprint="${ANDROID_RELEASE_CERT_SHA256//:/}"
[[ "${actual_fingerprint,,}" == "${expected_fingerprint,,}" ]]

badging="$(
  "$ANDROID_SDK_ROOT/build-tools/36.0.0/aapt" dump badging "$apk"
)"
rg -q "^package: name='ai.codegeist.app' " <<< "$badging"
rg -qx "sdkVersion:'33'" <<< "$badging"

archive_listing="$(unzip -Z1 "$apk")"
rg -q '^lib/arm64-v8a/' <<< "$archive_listing"
rg -q '^lib/x86_64/' <<< "$archive_listing"
! rg -q '^lib/armeabi-v7a/' <<< "$archive_listing"
! rg -qi '\.gguf$' <<< "$archive_listing"
! rg -qi '\.(jks|keystore)$' <<< "$archive_listing"
sha256sum "$apk"
```

Verification must report a valid signature, the intended release certificate,
and minimum SDK 33. The archive must contain both supported ABIs and no
`lib/armeabi-v7a/`, `.gguf`, or keystore.

After the build, remove signing values from the shell environment:

```bash
unset ANDROID_RELEASE_KEYSTORE_PATH
unset ANDROID_RELEASE_KEYSTORE_PASSWORD
unset ANDROID_RELEASE_KEY_PASSWORD
unset ANDROID_RELEASE_KEY_ALIAS
unset ANDROID_RELEASE_CERT_SHA256
```

## Install And Update

A debug APK uses a different key and cannot be upgraded in place to the local
release APK. Use a clean device or uninstall the debug package first,
understanding that uninstalling removes all Codegeist data and the downloaded
model:

```bash
adb uninstall ai.codegeist.app
adb install build/app/outputs/flutter-apk/app-release.apk
```

Later APKs signed with the same release key and a higher version code can update
the existing direct installation:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Record the source commit, application version, APK SHA-256, release-certificate
fingerprint, and tested Android device for each distributed build. Never commit
the APK or signing material.

## Official References

- [Flutter Android deployment](https://docs.flutter.dev/deployment/android)
- [Android app signing](https://developer.android.com/studio/publish/app-signing)
