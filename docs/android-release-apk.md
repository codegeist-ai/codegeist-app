# Android Release APK

Runbook for maintaining the Codegeist signing identity and building a stable APK
locally for independent verification and direct updates.

## Boundary

The first canonical release key was established under T007 and its current
credentials are staged under the ignored `.codegeist/secrets/` directory on a
trusted local machine. An encrypted GitHub `release` environment copy lets
`.github/workflows/android-release-apk.yml` publish the current APK; the key and
passwords must never enter Git, workflow text, logs, chat, issues, or public
artifacts. The same release key must sign every later direct-install update for
Android to accept an in-place upgrade.

The repository-root `.dockerignore` excludes `.codegeist/secrets/` from Docker
build contexts. The opened workspace and devcontainer can still read the mounted
directory, so use only trusted local tooling while the signing files are present.

The APK requires Android 13 (API 33) or newer and contains `arm64-v8a` and
`x86_64` native code but no GGUF model weights. The first model load still
downloads and verifies the pinned model.

## Release Identity

- Package id: `ai.codegeist.app`
- Installed name: `Codegeist`
- Version source: `pubspec.yaml`
- APK output: `build/app/outputs/flutter-apk/app-release.apk`
- Certificate SHA-256:
  `2A0789CB791AAD8E139E583DA856D121975C74CD14F403EF0E890E6ABC20EDD4`

Increment the `pubspec.yaml` build number for every distributed update. Android
rejects an update with a lower version code even when its signature matches.

## Stage The Release Key

Reuse the canonical JKS, passwords, and alias established for the first public
Release. Do not generate a new key or rotate its credentials during later
release setup. The repository-root `.gitignore` excludes
`.codegeist/secrets/`; verify that rule before staging any value:

```bash
set -euo pipefail
git check-ignore -q .codegeist/secrets/credential-probe
install -d -m 0700 .codegeist/secrets
```

Stage these non-empty files with mode `0600`:

- `.codegeist/secrets/codegeist-release.jks`
- `.codegeist/secrets/keystore-password`
- `.codegeist/secrets/key-password`
- `.codegeist/secrets/key-alias`
- `.codegeist/secrets/certificate-sha256`
- `.codegeist/secrets/codegeist-release-certificate.pem`

Verify the local boundary without printing a credential:

```bash
set -euo pipefail
secrets_dir="$PWD/.codegeist/secrets"
test "$(stat -c '%a' "$secrets_dir")" = 700
for file in \
  codegeist-release.jks \
  keystore-password \
  key-password \
  key-alias \
  certificate-sha256 \
  codegeist-release-certificate.pem; do
  test -s "$secrets_dir/$file"
  test "$(stat -c '%a' "$secrets_dir/$file")" = 600
  git check-ignore -q "$secrets_dir/$file"
done

canonical_fingerprint=2A0789CB791AAD8E139E583DA856D121975C74CD14F403EF0E890E6ABC20EDD4
staged_fingerprint="$(< "$secrets_dir/certificate-sha256")"
staged_fingerprint="${staged_fingerprint//:/}"
[[ "${staged_fingerprint^^}" == "$canonical_fingerprint" ]]

export ANDROID_RELEASE_KEYSTORE_PASSWORD="$(
  < "$secrets_dir/keystore-password"
)"
export ANDROID_RELEASE_KEY_ALIAS="$(< "$secrets_dir/key-alias")"
keytool -list -v \
  -keystore "$secrets_dir/codegeist-release.jks" \
  -alias "$ANDROID_RELEASE_KEY_ALIAS" \
  -storepass:env ANDROID_RELEASE_KEYSTORE_PASSWORD
unset ANDROID_RELEASE_KEYSTORE_PASSWORD ANDROID_RELEASE_KEY_ALIAS
```

These six files are the sole local custody copy of the signing identity. GitHub
environment secrets cannot be read back as a replacement. Losing the private
key makes future in-place updates impossible; exposing it requires replacing the
direct-distribution identity and reinstalling the app.

## Build Locally

Run from the repository root inside the rebuilt project devcontainer. Build only
from the intended committed source; `git status --short` must produce no output:

```bash
set -euo pipefail
test -z "$(git status --short)"
git rev-parse HEAD
task verify
```

Load the existing local values into the release-build environment without
printing them or placing them in command arguments:

```bash
set -euo pipefail
secrets_dir="$PWD/.codegeist/secrets"
canonical_fingerprint=2A0789CB791AAD8E139E583DA856D121975C74CD14F403EF0E890E6ABC20EDD4
export ANDROID_RELEASE_KEYSTORE_PATH="$secrets_dir/codegeist-release.jks"
export ANDROID_RELEASE_KEYSTORE_PASSWORD="$(
  < "$secrets_dir/keystore-password"
)"
export ANDROID_RELEASE_KEY_PASSWORD="$(< "$secrets_dir/key-password")"
export ANDROID_RELEASE_KEY_ALIAS="$(< "$secrets_dir/key-alias")"
export ANDROID_RELEASE_CERT_SHA256="$(< "$secrets_dir/certificate-sha256")"
configured_fingerprint="${ANDROID_RELEASE_CERT_SHA256//:/}"
[[ "${configured_fingerprint^^}" == "$canonical_fingerprint" ]]

cleanup_release_env() {
  unset ANDROID_RELEASE_KEYSTORE_PATH
  unset ANDROID_RELEASE_KEYSTORE_PASSWORD
  unset ANDROID_RELEASE_KEY_PASSWORD
  unset ANDROID_RELEASE_KEY_ALIAS
  unset ANDROID_RELEASE_CERT_SHA256
}
trap cleanup_release_env EXIT INT TERM
```

Build and verify the universal release APK:

```bash
set -euo pipefail
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
[[ "${actual_fingerprint^^}" == "$canonical_fingerprint" ]]

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
! rg -qi '\.(jks|keystore|p12|pfx|pem|key)$' <<< "$archive_listing"
! rg -qi '(^|/)(keystore-password|key-password|key-alias|certificate-sha256)$' \
  <<< "$archive_listing"
sha256sum "$apk"
```

Verification must report a valid signature, the intended release certificate,
and minimum SDK 33. The archive must contain both supported ABIs and no
`lib/armeabi-v7a/`, `.gguf`, signing material, or credential staging file.

After the build, remove signing values from the shell environment:

```bash
cleanup_release_env
trap - EXIT INT TERM
unset -f cleanup_release_env
```

The ignored local files remain under custodian control after the shell values
are unset. Keep all six signing-identity files under `.codegeist/secrets/` with
their restrictive modes.

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
