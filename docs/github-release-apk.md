# GitHub Release APK

Public direct-install runbook for signing and publishing the current Codegeist
APK without an application store.

## Boundary

The manually triggered `.github/workflows/android-release-apk.yml` workflow runs
only for the committed `main` branch through the protected GitHub `release`
environment. It builds one release-signed universal APK containing `arm64-v8a`
and `x86_64` native code and requires Android 13 (API 33) or newer.

The only uploaded binary asset is `codegeist.apk`; GitHub also provides its
standard source-code archives. The APK contains the public signing certificate
but never the private keystore, passwords, GGUF model weights, or other
credentials. The first model load still downloads and verifies the pinned model.

## Protect The GitHub Environment

Create a GitHub environment named `release` before the first run. Restrict its
deployment branches to protected `main`, require an authorized reviewer, enable
immutable Releases for the repository, and limit repository administration and
workflow changes to release custodians. The workflow's `main` check is defense
in depth; the platform environment rule is the boundary that prevents an
untrusted branch from receiving signing values. The workflow rejects and removes
a newly published Release when immutability is not active.

Repository or organization Actions policy must also allow the workflow's
job-scoped `GITHUB_TOKEN` to receive `contents: write`; that permission is used
only by the publication job to create the versioned Release, tag, and APK asset.

An authorized repository administrator can enable and verify immutable Releases
through GitHub's repository endpoint:

```bash
gh api --method PUT \
  repos/codegeist-ai/codegeist-app/immutable-releases \
  --silent
test "$(
  gh api repos/codegeist-ai/codegeist-app/immutable-releases \
    --jq '.enabled'
)" = true
```

Configure these encrypted environment secrets:

- `ANDROID_RELEASE_KEYSTORE_BASE64`
- `ANDROID_RELEASE_KEYSTORE_PASSWORD`
- `ANDROID_RELEASE_KEY_PASSWORD`
- `ANDROID_RELEASE_KEY_ALIAS`

Configure `ANDROID_RELEASE_CERT_SHA256` as an environment variable. The
certificate fingerprint is public and lets the workflow reject a valid APK
signed by an unexpected key.

The canonical certificate SHA-256 is
`2A0789CB791AAD8E139E583DA856D121975C74CD14F403EF0E890E6ABC20EDD4`. Treat this
tracked public value as the independent trust root when checking the staged JKS,
environment variable, workflow output, and downloaded APK.

GitHub limits individual secret values to 48 KB. The Base64-encoded JKS staged
through [`android-release-apk.md`](android-release-apk.md) must stay below that
limit; Base64 expands the raw file by roughly one third. Base64 is only transport
encoding, so the encoded keystore remains private signing material.

The private Gitea-to-GitHub mirror does not copy environments, secrets,
variables, approvals, or Actions settings. Configure this environment directly
on `https://github.com/codegeist-ai/codegeist-app` and never paste signing values
into chat or tracked files.

## Configure Signing Values

The existing canonical identity is staged under the repository's ignored
`.codegeist/secrets/` directory. The directory must use mode `0700`; the JKS,
password, alias, and fingerprint files must be non-empty and use mode `0600`.
Verify the ignore and file contracts before reading any value:

```bash
set -euo pipefail
secrets_dir="$PWD/.codegeist/secrets"
test "$(stat -c '%a' "$secrets_dir")" = 700
for file in \
  codegeist-release.jks \
  keystore-password \
  key-password \
  key-alias \
  certificate-sha256; do
  test -s "$secrets_dir/$file"
  test "$(stat -c '%a' "$secrets_dir/$file")" = 600
  git check-ignore -q "$secrets_dir/$file"
done

canonical_fingerprint=2A0789CB791AAD8E139E583DA856D121975C74CD14F403EF0E890E6ABC20EDD4
staged_fingerprint="$(< "$secrets_dir/certificate-sha256")"
staged_fingerprint="${staged_fingerprint//:/}"
[[ "${staged_fingerprint^^}" == "$canonical_fingerprint" ]]
```

Verify GitHub CLI authentication, then send the keystore to the protected
environment without placing its bytes in shell history or command arguments:

```bash
set -euo pipefail
gh auth status --hostname github.com
(
  set -euo pipefail
  secrets_dir="$PWD/.codegeist/secrets"
  encoded_keystore="$(
    base64 -w 0 "$secrets_dir/codegeist-release.jks"
  )"
  test -n "$encoded_keystore"
  (( ${#encoded_keystore} <= 49152 ))
  printf '%s' "$encoded_keystore" |
    gh secret set ANDROID_RELEASE_KEYSTORE_BASE64 \
      --repo codegeist-ai/codegeist-app \
      --env release
)
```

Send the existing passwords and alias directly from their local files. GitHub
CLI encrypts each secret before upload:

```bash
set -euo pipefail
secrets_dir="$PWD/.codegeist/secrets"
gh secret set ANDROID_RELEASE_KEYSTORE_PASSWORD \
  --repo codegeist-ai/codegeist-app \
  --env release < "$secrets_dir/keystore-password"
gh secret set ANDROID_RELEASE_KEY_PASSWORD \
  --repo codegeist-ai/codegeist-app \
  --env release < "$secrets_dir/key-password"
gh secret set ANDROID_RELEASE_KEY_ALIAS \
  --repo codegeist-ai/codegeist-app \
  --env release < "$secrets_dir/key-alias"
```

Store the verified public SHA-256 fingerprint as an environment variable:

```bash
set -euo pipefail
secrets_dir="$PWD/.codegeist/secrets"
canonical_fingerprint=2A0789CB791AAD8E139E583DA856D121975C74CD14F403EF0E890E6ABC20EDD4
staged_fingerprint="$(< "$secrets_dir/certificate-sha256")"
staged_fingerprint="${staged_fingerprint//:/}"
[[ "${staged_fingerprint^^}" == "$canonical_fingerprint" ]]
gh variable set ANDROID_RELEASE_CERT_SHA256 \
  --repo codegeist-ai/codegeist-app \
  --env release < "$secrets_dir/certificate-sha256"
```

Do not run these commands with placeholder signing values. Verify the configured
secret and variable names in the GitHub environment before enabling a release.

## Publish On GitHub

Increment the build number in `pubspec.yaml` before every distributed update,
commit the intended source to `main`, and wait for the GitHub mirror to receive
that commit. Then:

1. Open the repository's **Actions** tab.
2. Select **Android release APK**.
3. Select **Run workflow** on `main`.
4. Approve the protected `release` environment deployment.
5. Wait for analysis, widget tests, release signing, certificate verification,
   ABI inspection, model-weight exclusion, and publication to pass.
6. Open the permanent direct-download link:

   `https://github.com/codegeist-ai/codegeist-app/releases/latest/download/codegeist.apk`

Each successful run creates a normal Release tagged with the exact Flutter
version, for example `v0.1.0+1`, and marks it **Latest**. The workflow rejects a
reused or non-increasing build number, creates and verifies the Release as a
draft, records the source commit and APK SHA-256, and publishes only the verified
draft. It then checks immutable status and downloads the public **Latest** URL to
verify its bytes. Previous Releases remain available for provenance, while the
stable **Latest** URL follows the new version. There is no public ZIP wrapper or
Actions-artifact retention deadline.

If a post-publication immutability or public-download check fails, treat the
workflow as failed and inspect the newly published Release before distributing
its link. An immutable tag cannot be reused; publish a corrected build with a
higher build number instead of attempting to overwrite its asset.

## Verify The Download

Inside the project devcontainer, verify the downloaded file before installation:

```bash
set -euo pipefail
tag=v0.1.0+1
apk=/path/to/codegeist.apk
test -s "$apk"
sha256sum "$apk"
gh release verify "$tag" --repo codegeist-ai/codegeist-app
gh release verify-asset "$tag" "$apk" \
  --repo codegeist-ai/codegeist-app
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
canonical_fingerprint=2A0789CB791AAD8E139E583DA856D121975C74CD14F403EF0E890E6ABC20EDD4
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
```

The SHA-256 must match the immutable GitHub Release attestation and notes, and
the certificate must match the tracked Codegeist release fingerprint.

## Install And Update

On an Android 13 or newer ARM64 phone:

1. Open the direct-download URL in the phone's browser.
2. Download and open `codegeist.apk` from the browser or Downloads app.
3. If prompted, allow **Install unknown apps** for that browser or file manager.
4. Confirm the Android installation prompt.

No GitHub account, USB connection, ZIP extraction, or application store is
required for the public repository asset. Device policy or Play Protect may
still warn about or block sideloaded applications.

A previously installed debug build uses a different key and cannot be upgraded
in place. Uninstall it once, understanding that this removes all Codegeist app
data and the downloaded model:

```bash
adb uninstall ai.codegeist.app
adb install /path/to/codegeist.apk
```

Later APKs signed by the same release key and carrying a higher version code can
update the installed application without deleting its data:

```bash
adb install -r /path/to/codegeist.apk
```
