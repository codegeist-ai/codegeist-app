# T007: Publish First GitHub Release

- ID: `T007`
- Type: `release`
- Parent: none
- Status: `solved`

## Goal

Publish and independently verify `v0.1.0+1` as the first public Codegeist
Android release from committed `main` source.

## Context

T006 implemented the signed APK build, protected GitHub Actions workflow, and
release runbooks but left the real signing setup and first publication blocked.
The initial T007 preflight found no tags, Releases, prior manual runs, protected
branch, release environment, or local release identity. GitHub and local `main`
then pointed to `2e4d8191d12b25e600fd08c8ec29a8e9572262de`, whose
`pubspec.yaml` version was `0.1.0+1`.

The custodian explicitly authorized generation of the first canonical Android
release identity after no existing keystore could be located. The first workflow
attempt exposed an `sdkmanager` path error before signing; the minimal fix in
commit `b936923d562ce28792bbb2f1fca10ff2c2fc57b2` became the verified source for
the successfully published first Release.

## Scope

- Authenticate GitHub CLI through its browser flow and verify authorized access
  to `codegeist-ai/codegeist-app`.
- Confirm that the checkout is clean, local and GitHub `main` still identify the
  intended commit, and `v0.1.0+1` remains unused.
- Verify the protected GitHub `release` environment, required reviewer and
  branch restrictions, immutable Release policy, Actions permissions, four
  required signing-secret names, and public certificate-fingerprint variable.
- Stop before dispatch if any release control or signing input is absent. Report
  the exact blocker without reading or exposing secret values.
- Run the secrets-free local `task verify` contract before publication.
- Dispatch `.github/workflows/android-release-apk.yml` on `main`, obtain the
  protected-environment approval, and monitor the complete workflow result.
- Verify the published tag, source commit, Release state, asset set, public
  latest redirect, APK digest, signing certificate, package identity, minimum
  SDK, native ABIs, and exclusion of model weights and signing material.
- Record the published URL, source commit, version, APK SHA-256, and certificate
  fingerprint in the task implementation notes without recording private
  signing values.

## Non-Goals

- Change application behavior, dependencies, Android configuration, or the
  selected `0.1.0+1` version. Limit any release-blocking workflow correction to
  the smallest independently verified fix.
- Create or replace the canonical release key without explicit authorization
  from its custodian.
- Place a keystore, password, token, generated APK, or other credential in Git,
  chat, task documentation, command arguments, or logs.
- Publish from a branch or commit other than the confirmed GitHub `main` head.
- Perform physical-device installation; T006 records that separate verification.

## Acceptance Criteria

- `task verify` passes from a clean checkout at the intended source commit.
- GitHub CLI is authenticated as an account authorized to run and approve the
  release workflow.
- The `release` environment exposes all required secret and variable names only
  under the documented protection rules; secret values are never inspected or
  printed.
- The manual workflow succeeds for GitHub `main` commit
  `b936923d562ce28792bbb2f1fca10ff2c2fc57b2`.
- GitHub publishes one immutable, non-draft, non-prerelease Latest Release tagged
  `v0.1.0+1` with only `codegeist.apk` as its binary asset.
- The Release tag resolves to the intended source commit and its notes contain
  the matching application version, commit, and APK SHA-256.
- The stable latest URL downloads the exact published APK bytes.
- Android tooling verifies exactly one expected signer, package
  `ai.codegeist.app`, minimum SDK 33, and ARM64 plus x86_64 payloads.
- The APK contains no `armeabi-v7a`, GGUF model weights, JKS, or keystore files.
- The task records only non-secret release provenance and leaves generated APKs
  outside Git.

## Relevant Files Or Areas

- `.dockerignore`
- `.gitignore`
- `.codegeist/secrets/` (machine-local and ignored; never tracked)
- `.github/workflows/android-release-apk.yml`
- `pubspec.yaml`
- `docs/github-release-apk.md`
- `docs/android-release-apk.md`
- `docs/tasks/T006_distribute_android_apks_directly.md`
- `docs/tasks/README.md`

## Implementation Hints

- Verify GitHub CLI authentication before administrative operations; never copy
  token values into the repository, local signing files, command arguments, or
  logs.
- Treat missing or inconsistent GitHub environment controls as a blocker. Use
  the authorized canonical keystore only through the secure process in
  `docs/github-release-apk.md` if configuration is required.
- Use `gh workflow run android-release-apk.yml --ref main` only after all
  preflight checks pass, then watch the exact resulting run with exit-status
  propagation.
- Download verification artifacts to a temporary or ignored path and remove
  them after recording non-secret provenance.
- Do not retry publication with the same version after an immutable tag is
  created. A correction requires a separately approved higher build number.

## Local Secret Staging Contract

The authorized custodian selected `.codegeist/secrets/` as the machine-local
staging location for the canonical release identity. Add
`/.codegeist/secrets/` to the repository-root `.gitignore` and prove the ignore
rule with `git check-ignore` before creating or copying any credential file.
The directory must use mode `0700`; every file must use mode `0600`.

The local layout is:

```text
.codegeist/secrets/
|-- codegeist-release.jks
|-- keystore-password
|-- key-password
|-- key-alias
|-- certificate-sha256
`-- codegeist-release-certificate.pem
```

The custodian initially selected an existing identity, then explicitly
authorized one-time generation after no JKS could be found. The password and
alias files intentionally contain the newly generated values in plain text at
the custodian's request. This identity is now canonical and must not be
regenerated, rotated, or replaced for later updates without a separately
approved migration. The files remain machine-local, must never enter Git, and
must never be printed, placed in command arguments, or included in logs or task
notes.

Upload the same values to the protected GitHub `release` environment through
standard input as `ANDROID_RELEASE_KEYSTORE_BASE64`,
`ANDROID_RELEASE_KEYSTORE_PASSWORD`, `ANDROID_RELEASE_KEY_PASSWORD`, and
`ANDROID_RELEASE_KEY_ALIAS`. Store the public normalized certificate fingerprint
as the environment variable `ANDROID_RELEASE_CERT_SHA256`. GitHub Actions cannot
read the local `.codegeist/secrets/` directory; its encrypted environment copy is
therefore required for the hosted release build.

## Implementation Plan

1. Keep the task-documentation changes in the current worktree and perform the
   release checks from a separate temporary worktree at commit
   `b936923d562ce28792bbb2f1fca10ff2c2fc57b2`. Do not commit or push the task
   documentation before dispatch because GitHub `main` must still identify the
   intended release source.
2. Add the local ignore rule before creating `.codegeist/secrets/`, apply the
   required directory and file modes, and confirm that Git ignores every staged
   credential path.
3. Generate the first canonical JKS only after explicit custodian authorization,
   store its random passwords and alias under the documented filenames, validate
   the certificate fingerprint, and keep every private value inside the ignored
   local secret boundary without printing it.
4. Verify that GitHub CLI authenticates as `codegeist-ai` with `ADMIN`
   permission, and confirm that GitHub `main` still resolves to the intended
   commit. Require `pubspec.yaml` version `0.1.0+1` and no conflicting tag,
   draft, published Release, or unresolved run for the intended source commit.
5. Protect GitHub `main`, create the `release` environment with
   `codegeist-ai` as its required reviewer, preserve a usable approval path, and
   restrict deployment to protected branches. Re-read both resources and require
   GitHub to report the intended protection state.
6. Enable Release immutability with the repository immutable-Releases API,
   require its read endpoint to return `enabled: true`, and verify the published
   Release's `isImmutable` value independently afterward.
7. Send the JKS, staged passwords, and alias from the local files directly to
   the four protected environment secrets through standard input. Set the public
   certificate fingerprint as `ANDROID_RELEASE_CERT_SHA256`, then list and
   compare only secret and variable metadata.
8. Verify that GitHub Actions is enabled, its repository policy permits every
   full-SHA action used by the workflow, only the publication job declares
   `contents: write`, and all environment controls and signing names now pass.
   Stop before dispatch and record a non-secret blocker if any check fails.
9. Run `task verify` in the clean temporary worktree and confirm that it remains
   clean afterward. Immediately before dispatch, repeat the remote commit,
   version, tag, Release, environment, and signing-metadata checks to close the
   preflight race window.
10. Record the pre-dispatch workflow-run set and dispatch
   `android-release-apk.yml` once on `main`. Resolve the exact new run by its
   creation time, workflow, event, branch, and head SHA; verify the head SHA
   before requesting environment approval.
11. Obtain approval from the configured required reviewer, then watch that exact
    run with exit-status propagation. Never retry automatically. If the run
    fails, inspect whether a draft, tag, or immutable Release was created before
    deciding any recovery action; never reuse a tag after immutable publication.
12. Verify that `v0.1.0+1` is the immutable, non-draft, non-prerelease Latest
    Release, that its tag resolves to the intended commit, that its notes contain
    the version, commit, and APK SHA-256, and that `codegeist.apk` is its only
    binary asset.
13. Download both the versioned asset and the stable Latest URL to a temporary
    path outside the repository. Require byte equality and the Release-note
    digest, then independently verify one expected signer and certificate,
    package `ai.codegeist.app`, version name and code, minimum SDK 33, ARM64 and
    x86_64 payloads, and the absence of `armeabi-v7a`, GGUF, JKS, and keystore
    files.
14. Remove the temporary APKs and worktree, but retain the ignored local signing
    files with their restrictive modes until the custodian chooses a different
    storage policy. Record only the authenticated preflight result, workflow and
    Release URLs, source commit, version, APK
    SHA-256, and public certificate fingerprint in this task. Mark T007 `solved`
    only after every check passes, and update T006 with the publication result
    without claiming physical-device verification from T007.
15. Finish with `git --no-pager diff --check` and a repository status check that
    proves no APK, keystore, credential, or other generated release material was
    added to Git.

## Verification

Preflight and local verification:

```bash
set -euo pipefail
expected_commit=b936923d562ce28792bbb2f1fca10ff2c2fc57b2
test -z "$(git status --short)"
test "$(git rev-parse HEAD)" = "$expected_commit"
remote_commit="$(
  git ls-remote \
    https://github.com/codegeist-ai/codegeist-app.git \
    refs/heads/main |
    cut -f1
)"
test "$remote_commit" = "$expected_commit"
gh auth status --hostname github.com
gh secret list --repo codegeist-ai/codegeist-app --env release
gh variable list --repo codegeist-ai/codegeist-app --env release
task verify
test -z "$(git status --short)"
```

Inspect the successfully completed protected workflow without dispatching the
immutable version again:

```bash
set -euo pipefail
run_id=32420779152
gh run watch "$run_id" --repo codegeist-ai/codegeist-app --exit-status
```

Inspect the Release and apply the APK checks documented in
`docs/github-release-apk.md`:

```bash
set -euo pipefail
gh release view v0.1.0+1 \
  --repo codegeist-ai/codegeist-app \
  --json tagName,targetCommitish,isDraft,isPrerelease,isImmutable,assets,url
gh release verify v0.1.0+1 --repo codegeist-ai/codegeist-app
git --no-pager diff --check
```

## Dependencies

- T006 release implementation and runbooks.
- Authorized GitHub access to `codegeist-ai/codegeist-app`.
- The canonical release identity under an assigned custodian's local control.
- A protected GitHub `release` environment with required reviewer, protected
  `main` restriction, immutable Releases, signing secrets, and certificate
  fingerprint.
- GitHub Actions and public network access.
- The project-pinned Flutter, JDK 21, and Android SDK toolchain.

## Open Questions

- None.

## Implementation Notes

On 2026-08-20, GitHub CLI authenticated as `codegeist-ai` with `ADMIN`
permission for `codegeist-ai/codegeist-app`. No token or signing secret value
was recorded in tracked files or user-facing output.

The setup protected `main` against force pushes and deletion, created the
`release` environment with `codegeist-ai` as required reviewer and
protected-branch deployments, enabled immutable Releases, and installed the four
required encrypted signing secrets plus the public fingerprint variable.
Read-back checks confirmed every control without retrieving a secret value.

After the custodian explicitly authorized a new first identity, a 4096-bit RSA
JKS and independent random keystore and key passwords were generated under the
ignored `.codegeist/secrets/` directory. The six canonical local files use mode
`0600`; the directory uses `0700`. The public release certificate SHA-256
fingerprint is
`2A0789CB791AAD8E139E583DA856D121975C74CD14F403EF0E890E6ABC20EDD4`.

`task verify` passed from clean temporary worktrees at the initial source and
the final release commit. A separate local release build with the canonical key
also verified its signer, fingerprint, package, version, minimum SDK, ABIs, and
archive exclusions. All temporary worktrees and locally built APKs were removed.

The first workflow run,
`https://github.com/codegeist-ai/codegeist-app/actions/runs/32420235869`, failed
before signing because GitHub's Ubuntu runner did not put `sdkmanager` on
`PATH`. Commit `b936923d562ce28792bbb2f1fca10ff2c2fc57b2` changed the workflow
to invoke the tool through the configured Android SDK root. The private Gitea
origin could not accept that commit because its Caddy local CA is not trusted in
the development environment and SSH port 22 is closed, so the verified
fast-forward commit was pushed directly to GitHub to unblock publication. The
path correction was T007's only workflow-scope deviation during publication and
changed no application or signing behavior.

The successful protected workflow run is
`https://github.com/codegeist-ai/codegeist-app/actions/runs/32420779152`. It
published the immutable Latest Release at
`https://github.com/codegeist-ai/codegeist-app/releases/tag/v0.1.0%2B1` from
commit `b936923d562ce28792bbb2f1fca10ff2c2fc57b2`. The version is `0.1.0+1`,
and the 61,709,852-byte `codegeist.apk` SHA-256 is
`b3e6352214df3eb16a75fef00e37014d3322ffa61f953a9215b943218526da6b`.

Independent downloads from the versioned Release and stable Latest URL were
byte-identical. Android tooling confirmed exactly one expected signer, package
`ai.codegeist.app`, version name `0.1.0`, version code 1, minimum SDK 33, ARM64
and x86_64 payloads, no `armeabi-v7a`, GGUF, keystore, private-key, certificate,
password, or alias staging files. GitHub's immutable Release attestation also
verified the tag, source commit, asset name, and digest. T007 itself did not
perform physical-device installation; T006 later recorded the successful public
Latest installation and launch on a Samsung Galaxy Z Fold6.
