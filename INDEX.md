# Repository Index

Navigation map for the minimal Android-only Flutter application and its
implementation tasks.

## When To Read This

- Read this before adding application code, Android configuration, model
  artifacts, inference runtimes, or project automation.

## Directory Map

- `README.md` - current application boundary, toolchain, build, and AVD usage.
- `LICENSE` - 0BSD terms for Codegeist-authored repository content.
- `.gitignore` - machine-local workspace files excluded from Git.
- `.gitmodules` - shared-kit sources and release-branch tracking.
- `.devcontainer/` - shared development environment on its `release` branch.
- `.opencode/` - shared OpenCode agent kit on its `release` branch.
- `.codegeist/Dockerfile` - pinned Flutter, JDK, Android SDK, and scrcpy
  extension for the shared devcontainer image.
- `.github/workflows/android-release-apk.yml` - manually signs and publishes the
  current universal release APK at one stable direct-download URL.
- `Taskfile.yml` - named Flutter verification, local signed release APK, and
  Android AVD entrypoints.
- `pubspec.yaml` - Flutter package metadata and dependencies.
- `assets/brand/` - approved app-local Codegeist logo and its pinned design
  provenance record.
- `lib/main.dart` - pinned model loader, local inference chat, and runtime
  entrypoint.
- `test/widget_test.dart` - lightweight regression contract for the model-load
  screen and Alpha Preview disclosure.
- `android/` - generated Android platform project for `ai.codegeist.app`.
- `scripts/android-avd.sh` - KVM AVD creation, boot, APK installation, launch,
  process verification, and visible scrcpy mirroring.
- `scripts/android-smoke.sh` - Android process, activity, UI semantics, and MP4
  smoke-test contract.
- `docs/assets/codegeist-smoke.gif` - compact README preview derived from the
  smoke-test recording's meaningful launch frames.
- `docs/github-release-apk.md` - protected GitHub release build, direct download,
  verification, sideload, and stable-update contract.
- `docs/android-release-apk.md` - local release-key generation, signing,
  verification, installation, and stable direct-update contract.
- `docs/tasks/` - scoped application task specifications and their template.

## Known Directory Indexes

- `INDEX.md` - this repository-root index.

## Key Workflows

- Initialize shared kits with `git submodule update --init .devcontainer
  .opencode`.
- Rebuild the project devcontainer after `.codegeist/Dockerfile` changes.
- Run `task verify` inside the rebuilt devcontainer for analysis, tests, and the
  debug APK build.
- Run `task apk` with the documented `ANDROID_RELEASE_*` environment to create
  one universal ARM64/x86_64 release APK for stable direct installation.
- Manually run **Android release APK** from `main` to publish a versioned Release
  and replace the stable **Latest** direct-download target.
- Run `task android` for the headless Android baseline or
  `task android:visible` when the devcontainer has a usable X11 transport.
- Review `docs/tasks/T001_bootstrap_minimal_flutter_android_app.md` for the
  verified minimal Flutter and Android AVD contract.
- Review `docs/tasks/T002_show_codegeist_start_screen.md` for the first visible
  start-screen behavior.
- Review `docs/tasks/T003_use_scrcpy_for_visible_android.md` for SSH-X11-safe
  Android screen mirroring.
- Review `docs/tasks/T004_add_android_smoke_test.md` for runtime smoke checks and
  local MP4 capture.
- Review `docs/tasks/T005_build_minimal_local_codegeist_chat.md` for the pinned
  model download and minimal local Android chat contract.
- Review
  `docs/tasks/T006_distribute_android_apks_directly.md` for protected GitHub and
  local release signing, direct APK distribution, and the Alpha disclosure.

## Update Triggers

- Update this index when top-level files, directories, entrypoints, or primary
  task references change.

## Agent Notes

- Treat every committed ref as public because GitHub mirrors Gitea Git refs.
- Do not add model weights, generated SDK or AVD artifacts, APKs, credentials,
  or product behavior without a focused implementation task.
- Keep Android builds on the project-pinned JDK 21; the shared JDK 25 fails this
  toolchain's `JdkImageTransform`.
- Keep direct tool downloads and explicitly versioned Android packages pinned,
  but let Google's rolling Platform Tools, emulator, API platform, and system
  image revisions follow the current SDK repository unless a concrete need
  justifies stricter drift guards.
