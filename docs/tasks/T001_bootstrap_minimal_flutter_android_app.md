# T001: Bootstrap Minimal Flutter Android App

- ID: `T001`
- Type: `feature`
- Parent: none
- Status: `solved`

## Goal

Create the smallest runnable Android-only Flutter application and provide a
reproducible workflow that boots an Android Virtual Device (AVD), installs the
application, starts it, and verifies that it is running.

## Context

The repository currently contains documentation and shared workspace submodules
only. The shared devcontainer provides QEMU/KVM packages, passes `/dev/kvm`
through to its privileged workspace container, and supports X11, but it does not
provide Flutter, the Android SDK, or an Android emulator configuration.

The first application increment must establish only a working Flutter and
Android baseline. It must not introduce product behavior that could obscure
whether the basic build and emulator path works.

## Scope

- Create a Flutter project in the repository root with Dart project name
  `codegeist_app` and Android package ID `ai.codegeist.app`.
- Generate and retain only the Android platform target needed by this task.
- Render one empty application surface with no text, controls, navigation,
  branding, counter example, or other visible feature.
- Add a project-local `.codegeist/Dockerfile` extension that installs a mutually
  compatible Flutter, Java, and Android toolchain. Pin direct downloads and
  explicitly addressable packages while allowing Google's rolling SDK packages
  to follow the current repository.
- Keep SDKs and package caches outside Git while making their installation
  reproducible through the devcontainer image build.
- Create one named x86_64 AVD non-interactively when it does not exist and reuse
  it on later runs.
- Provide a non-interactive repository entrypoint that starts the AVD with KVM,
  waits for Android to finish booting, builds and installs the debug APK, starts
  `ai.codegeist.app`, and verifies its process through ADB.
- Make headless AVD startup the default verification path.
- Support an explicit visible mode through the devcontainer's existing display
  transport and fail before emulator startup with an actionable message when no
  usable display is available.
- Document the development-environment rebuild and both AVD startup modes in the
  root `README.md`.
- Update `.gitignore` and the root `INDEX.md` for the generated Flutter, Android,
  emulator, and task paths introduced by the implementation.

## Non-Goals

- Codegeist model download, loading, or inference.
- Network access, persistence, settings, permissions, telemetry, or analytics.
- Product UI, themes, assets, localization, navigation, or state management.
- Release signing, Play Store packaging, or production deployment.
- iOS, web, desktop, or embedded Flutter targets.
- Physical Android-device support.
- Modification of the shared `.devcontainer` or `.opencode` submodule contents.
- Shipping SDK archives, AVD images, APKs, generated build output, credentials,
  or other machine-local artifacts in Git.

## Acceptance Criteria

- The repository root is recognized as a Flutter project named
  `codegeist_app`, and only the Android platform project is present.
- The Android namespace and application ID are both `ai.codegeist.app`.
- Launching the app displays an empty surface and no user-visible text or
  interactive element.
- Direct toolchain downloads and explicitly addressable Android SDK packages are
  versioned, while Google's rolling emulator, Platform Tools, platform, and
  system-image revisions may follow the current SDK repository.
- `flutter analyze` completes successfully.
- `flutter test` completes successfully and includes a widget-level regression
  check for the empty application surface.
- `flutter build apk --debug` creates an installable debug APK.
- The repository entrypoint creates the named AVD without interactive input when
  it is absent and does not recreate it unnecessarily.
- The headless path starts the emulator with KVM acceleration, waits for a fully
  booted ADB device, installs the debug APK, launches `ai.codegeist.app`, and
  exits successfully only after ADB confirms its running process.
- The visible mode performs the same build, install, launch, and process checks
  while displaying the emulator through a valid devcontainer display transport.
- Visible mode exits with a clear diagnostic when no usable display transport is
  available.
- The startup workflow is deterministic, non-interactive, and cleans up an
  emulator process that it started when a later step fails or the workflow is
  interrupted.
- No product behavior or unsupported Flutter platform target is introduced.
- `git --no-pager diff --check` reports no errors.

## Relevant Files Or Areas

- `pubspec.yaml`
- `lib/main.dart`
- `test/`
- `android/`
- `.codegeist/Dockerfile`
- `scripts/`
- `.gitignore`
- `README.md`
- `INDEX.md`

## Implementation Hints

- Start from Flutter's `empty` application template and remove any remaining
  visible sample content rather than hand-authoring a partial platform project.
- Use a stable Flutter release and a Java version supported by the generated
  Flutter Android Gradle toolchain. Record exact versions rather than tracking
  floating `latest` downloads.
- Install Android SDK packages with `sdkmanager`, accept their licenses during
  the image build, and use `avdmanager` for idempotent AVD creation.
- Use an x86_64 system image so the existing `/dev/kvm` passthrough can
  accelerate the emulator. Verify acceleration before waiting for Android boot.
- Keep all AVD lifecycle behavior in one small Bash entrypoint with explicit
  mode selection. A Taskfile may expose thin aliases but must not duplicate the
  script's setup, cleanup, or verification logic.
- Use stable, line-oriented operation logs on stderr and reserve any documented
  stdout payload for machine consumption.
- Detect boot completion through ADB state and Android boot properties rather
  than a fixed sleep.
- Select the workflow's emulator by its ADB serial so another attached device or
  emulator cannot receive the APK accidentally.
- Prefer software-compatible emulator graphics in headless mode. Visible mode
  may use the existing X11 transport but must not weaken host display security.

## Verification

Run these checks inside the rebuilt project devcontainer:

```bash
flutter doctor -v
flutter analyze
flutter test
flutter build apk --debug
scripts/android-avd.sh headless
scripts/android-avd.sh visible
git --no-pager diff --check
```

The visible invocation requires a usable display transport. When one is not
available, verify its documented failure message instead of treating the missing
host display as an application failure.

## Dependencies

- A Linux x86_64 host that exposes a readable and writable `/dev/kvm` device to
  the devcontainer.
- Docker and the Dev Containers workflow already provided by `.devcontainer/`.
- Network access while building the development image and downloading Android
  SDK packages.
- A valid X11 display transport only for optional visible AVD startup.

## Open Questions

- None.

## Implementation Notes

Implemented the Android-only Flutter project from Flutter 3.47.0's official
empty template and reduced `MainApp` to an empty `MaterialApp` and `Scaffold`.
The Android namespace, application ID, and Kotlin package are
`ai.codegeist.app`.

The project devcontainer extension pins Flutter 3.47.0, Dart 3.13.0, Temurin
JDK 21.0.12+8, Android command-line tools build 15859902, Build Tools 36.0.0,
and NDK 28.2.13676358. Platform Tools, the emulator, API 36 platform revision,
and Google APIs x86_64 system-image revision follow Google's current SDK
repository. Direct downloads remain checksum-verified. The shared GraalVM JDK
25 was tested but cannot replace JDK 21 because the Android build fails in
Gradle's `JdkImageTransform` while invoking its `jlink`.

`scripts/android-avd.sh` creates or reuses `codegeist_api_36`, normalizes its
data partition for the minimal test workload, reserves `emulator-5556`, checks
KVM, waits on ADB boot state, builds and installs the debug APK, starts the
activity, and verifies the application process. A repeated invocation reuses a
running `codegeist_api_36` but rejects an unrelated AVD on the reserved serial.
The headless workflow completed successfully during implementation. Visible
mode refreshes the workspace's generated display value, normalizes SSH
Xauthority aliases without exposing the cookie, and completed successfully with
`MainActivity` resumed. The current SSH-X11 transport creates the emulator's Qt
window but leaves its guest display surface gray. ADB screenshots confirm that
the Android framebuffer itself renders the application correctly, so this is a
host display-transport limitation rather than an application failure. T003
replaces that native visible window with a software-rendered scrcpy mirror.

`Taskfile.yml` exposes the established Flutter checks as `analyze`, `test`,
`build`, and sequential `verify` tasks. Its `android` and `android:visible`
tasks delegate directly to `scripts/android-avd.sh` without duplicating AVD
lifecycle behavior. Flutter tasks run an internal `flutter pub get` once per
top-level Task invocation so a rebuilt container cannot retain stale package
paths from the workspace-local `.dart_tool` directory.

Verification completed with `task verify`, `scripts/android-avd.sh headless`,
`task android:visible`, direct ADB activity and process inspection,
`bash -n scripts/android-avd.sh`, and `git --no-pager diff --check`.
