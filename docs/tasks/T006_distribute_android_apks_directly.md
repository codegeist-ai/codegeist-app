# T006: Distribute Android APKs Directly

- ID: `T006`
- Type: `release`
- Parent: none
- Status: `blocked`

## Goal

Publish the current release-signed Android APK directly through GitHub without
an application store. Preserve a local recovery build path for the same signing
identity. Every distributed version must support stable direct updates, preserve
local model inference, exclude model weights, and show the Alpha Preview
disclosure before model loading.

## Context

Codegeist is an Android-only Flutter application for local GGUF inference. The
first model load downloads and verifies a pinned 1.11 GB artifact; prompts and
generated responses remain on the device under the current implementation.

The repository is written through private Gitea and mirrored publicly to GitHub.
Every committed ref and GitHub Release asset must therefore be treated as
public. The canonical release key remains under local encrypted custody; GitHub
Actions receives an encrypted environment copy only through explicitly mapped
secrets. Release-signing material must never enter Git, logs, chat, issues, or
uploaded assets.

## Scope

### Alpha Preview

- Show a blocking disclosure before every new model-load request.
- State that the model is small, experimental, local, and may produce inaccurate,
  incomplete, unsafe, or offensive text.
- State the approximate 1.11 GB first download and local prompt processing.
- State that output is not professional or expert advice.
- Require explicit `Continue`; `Cancel` must start no model work.
- Cover initial, disclosure, cancel, and continue behavior with deterministic
  widget tests that do not invoke native inference or network access.

### Android Identity

- Preserve package and namespace `ai.codegeist.app`.
- Display the installed name `Codegeist`.
- Require Android 13 (API 33) or newer for every distributed APK.
- Keep `pubspec.yaml` as the version name and version-code source.
- Increment the build number for every distributed direct-update release.

### Public GitHub Release APK

- Add one manually triggered `main`-only workflow using a protected GitHub
  environment named `release`.
- Restrict the environment to protected `main`, require an authorized reviewer,
  enable immutable Releases, and expose signing values only to the steps that
  need them.
- Grant the automatic job token `contents: write` only so the workflow can
  create the versioned public GitHub Release, tag, and APK asset.
- Use pinned full-SHA actions, Flutter 3.47.0, JDK 21, Android API 36, Build
  Tools 36.0.0, and NDK 28.2.13676358.
- Run dependency resolution, static analysis, widget tests, and a universal
  ARM64/x86_64 release APK build.
- Verify the pinned release-certificate fingerprint, minimum SDK 33, both
  required ABIs, and absence of `armeabi-v7a`, GGUF model weights, or signing
  material.
- Publish only `codegeist.apk` on a normal Release tagged with the exact Flutter
  version and mark that Release **Latest**.
- Keep one stable public **Latest** direct-download URL with no public ZIP
  wrapper or Actions-artifact retention deadline.
- Reject reused or non-increasing build numbers and record the application
  version, commit, and APK SHA-256 in the Release metadata.
- Create and verify each Release as a draft before publishing and enforcing its
  immutable tag and asset state.

### Local Release APK

- Configure release builds from four `ANDROID_RELEASE_*` environment values
  without a debug or unsigned fallback.
- Keep debug builds and `task verify` secrets-free.
- Build one universal ARM64/x86_64 APK through `task apk`.
- Generate the real release key interactively outside the checkout and back up
  its keystore, passwords, alias, certificate, and fingerprint before placing an
  encrypted copy in GitHub or making the first distribution.
- Verify each APK with Android `apksigner`, calculate its SHA-256, inspect both
  ABIs, and reject `armeabi-v7a`, GGUF, or key material.
- Use the same release key and a higher version code for every later in-place
  direct update.

### Documentation

- Document the protected GitHub environment, permanent direct link, APK
  download, certificate verification, sideloading, and one-time transition from
  a debug-signed installation.
- Document local release-key creation, backup, GitHub secret setup, interactive
  local environment setup, release APK verification, and stable direct updates.
- Keep all durable project text in English and all private signing values outside
  tracked files.

## Signing Contract

The authorized local operator exports only these values in a private shell:

- `ANDROID_RELEASE_KEYSTORE_PATH`
- `ANDROID_RELEASE_KEYSTORE_PASSWORD`
- `ANDROID_RELEASE_KEY_PASSWORD`
- `ANDROID_RELEASE_KEY_ALIAS`

Passwords are read interactively without terminal echo or shell-history
arguments. Unset all four values after a local build. GitHub stores the keystore
as `ANDROID_RELEASE_KEYSTORE_BASE64` and maps the two passwords and alias from
protected environment secrets into the release-build step. The public
certificate SHA-256 is stored separately as `ANDROID_RELEASE_CERT_SHA256` and
must match the built APK before publication.

## Non-Goals

- Any application-store packaging, publication, testing track, listing, account,
  policy declaration, or signing service.
- Publishing a debug-signed APK or public development artifact through GitHub.
- Bundling model weights in an APK or repository.
- Accounts, analytics, advertising, cloud inference, or remote chat storage.
- Claiming production quality, broad model capability, or guaranteed safe output.

## Acceptance Criteria

- Package identity remains `ai.codegeist.app` and the installed name is
  `Codegeist`.
- The distributed APK requires minimum SDK 33.
- The Alpha Preview disclosure and its cancel/continue paths are covered by four
  passing widget tests.
- `task verify` succeeds without signing values.
- `task apk` fails clearly without all four local signing values.
- A disposable local release key builds an APK whose signature verifies.
- The release APK contains ARM64 and x86_64 payloads, no `armeabi-v7a`, GGUF
  model weights, or signing material.
- The manual GitHub workflow runs only for `main`, uses the protected `release`
  environment, and publishes only the certificate-verified release APK through
  the stable **Latest** Release URL.
- Published Releases and their tags and assets are immutable.
- The public release documentation explains that switching once from a debug
  installation requires an uninstall and loss of local app data.
- The local release documentation explains key custody, version increments, and
  stable updates with the same release key.
- No signing material or generated APK is committed.

## Relevant Files Or Areas

- `.github/workflows/android-release-apk.yml`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/.gitignore`
- `Taskfile.yml`
- `pubspec.yaml`
- `lib/main.dart`
- `test/widget_test.dart`
- `README.md`
- `INDEX.md`
- `docs/github-release-apk.md`
- `docs/android-release-apk.md`
- `docs/assets/codegeist-smoke.gif`
- `docs/tasks/README.md`

## Verification

Run the secrets-free repository contract:

```bash
task verify
```

Create a disposable test keystore outside the checkout, export the four
signing values and its public certificate fingerprint, then verify the local
release APK:

```bash
task apk
apk=build/app/outputs/flutter-apk/app-release.apk
verification="$(
  "$ANDROID_SDK_ROOT/build-tools/36.0.0/apksigner" \
    verify --verbose --print-certs "$apk"
)"
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
! rg -qi '\.(gguf|jks|keystore)$' <<< "$archive_listing"
sha256sum "$apk"
git --no-pager diff --check
```

Parse the GitHub workflow, confirm that every reusable action uses a full commit
SHA, confirm that signing secrets are mapped only to signing steps, and inspect
the built release APK with the same certificate, SDK, ABI, model-weight, and
key-material checks.

## Dependencies

- T001 through T005.
- The pinned local Flutter, JDK 21, and Android toolchain.
- Public network access for dependencies, GitHub Actions, and first model load.
- A protected local release key and encrypted backup before distribution.
- A GitHub `release` environment restricted to protected `main`, an authorized
  reviewer, immutable Releases, the four signing secrets, and the public
  certificate fingerprint.
- An Android ARM64 device for final direct-install verification.

## Open Questions

- Who is the authorized custodian for the real direct-distribution release key?

## Implementation Notes

Every model-load request now passes through a non-dismissible Alpha Preview
dialog. `Cancel` starts no work and `Continue` invokes exactly one load request.
Four widget tests cover the initial screen and all disclosure branches. The
installed name is `Codegeist`; package identity remains `ai.codegeist.app`.

Release Gradle tasks require all four `ANDROID_RELEASE_*` values and have no
debug or unsigned fallback. `task apk` builds one universal release APK, while
debug development and `task verify` remain secrets-free.

A disposable local JKS built a 61,709,852-byte release APK after the Android 13
baseline was applied. Android `apksigner` verified its v2 signature; manifest
and archive inspection found minimum SDK 33, target SDK 36, ARM64 and x86_64
payloads, no `armeabi-v7a`, GGUF, or key material, and the disposable APK
SHA-256 was
`893d11bdd96054a95af8ea36eb6dde2638a4bbb108758a08fc55cc7f4859e3cf`.
The disposable keystore was removed after verification.

The manual GitHub workflow runs analysis and widget tests, builds one universal
release APK from protected environment signing values, verifies its certificate
and archive, rejects unsupported SDK, ABI, GGUF, and key-material payloads, and
publishes only `codegeist.apk` on one versioned normal Release marked **Latest**.
The publication job verifies the tag target, exact binary-asset set, and APK hash
while the Release remains a draft, then publishes it and confirms immutable
state and the public **Latest** download. Its stable redirect serves the APK
directly without a public ZIP or retention deadline. The private key is exposed
only to the keystore-preparation and release-build steps and is removed from the
runner immediately after signing.

`docs/github-release-apk.md` and `docs/android-release-apk.md` document the
public channel, protected signing identity, local recovery path, and one-time
transition from development signing. The compact README GIF is 320 by 712 pixels
at 8 FPS and 21.76 seconds; it holds the initial screen for about three seconds,
keeps the loaded-chat pause near one second, and shows the Alpha disclosure,
model preparation, prompt, and local response.

T006 remains `blocked`, not `solved`, until the real release key has an assigned
custodian and encrypted backup, the protected GitHub environment is configured,
and the release workflow is committed and successfully publishes and installs
`codegeist.apk` from GitHub.
