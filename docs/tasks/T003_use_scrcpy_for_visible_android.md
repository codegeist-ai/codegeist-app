# T003: Use Scrcpy For Visible Android

- ID: `T003`
- Type: `build`
- Parent: none
- Status: `solved`

## Goal

Make `task android:visible` display and control the running Android application
reliably over the devcontainer's SSH-X11 transport.

## Context

The Android Emulator's native Qt window opens over the current SSH-X11
connection but leaves its guest display surface uniformly gray. ADB screenshots
prove that Android and the application render correctly. A temporary scrcpy 4.1
test mirrored the same framebuffer through SDL's software renderer without the
gray output.

## Scope

- Install the official scrcpy 4.1 Linux x86_64 bundle in the project
  devcontainer with a pinned SHA-256 checksum.
- Start the visible workflow's AVD without its native Qt window.
- Mirror `emulator-5556` through scrcpy with audio disabled and SDL software
  rendering.
- Keep the mirror in the foreground while preserving the existing AVD identity,
  application installation, launch, verification, and failure cleanup rules.
- Document the visible workflow and devcontainer rebuild requirement.

## Non-Goals

- Audio forwarding, recording, camera mirroring, or physical-device support.
- Replacing ADB, the Android Emulator, or the headless verification workflow.
- Installing scrcpy in the shared `.devcontainer` submodule.

## Acceptance Criteria

- The rebuilt project devcontainer reports scrcpy 4.1.
- `task android:visible` starts or reuses `codegeist_api_36` on
  `emulator-5556`, installs and launches `ai.codegeist.app`, and opens a scrcpy
  window titled `Codegeist App`.
- The scrcpy window displays `codegeist` instead of a uniform gray surface over
  the current SSH-X11 transport.
- Closing the mirror completes the task normally and leaves a successfully
  started emulator running.
- `task android` retains its non-interactive headless behavior.
- `task verify` succeeds.

## Relevant Files Or Areas

- `.codegeist/Dockerfile`
- `scripts/android-avd.sh`
- `Taskfile.yml`
- `README.md`
- `INDEX.md`

## Implementation Hints

- Preserve the complete official scrcpy bundle so its client libraries and
  Android server remain version-aligned.
- Use `--render-driver=software` to avoid another accelerated host presentation
  path over SSH-X11.

## Verification

```bash
devcontainer up --workspace-folder .
scrcpy --version
task verify
task android
task android:visible
git --no-pager diff --check
```

## Dependencies

- The AVD workflow established by T001.
- A working SSH-X11 transport for the scrcpy window.

## Open Questions

- None.

## Implementation Notes

The project devcontainer extension installs the complete official scrcpy 4.1
Linux x86_64 bundle under `/opt/scrcpy`, verifies its published SHA-256 digest,
and exposes the client through `/usr/local/bin/scrcpy`. The client and Android
server therefore remain on the same pinned release.

Visible mode now validates the refreshed SSH-X11 display, prepares a private
runtime and Xauthority file, starts a new emulator without its native Qt window,
and runs scrcpy in the foreground with audio disabled and SDL software
rendering. Headless mode retains its previous non-interactive behavior and
stdout serial contract.

Verification completed with `scrcpy --version`, `task verify`, repeated
`task android`, and `task android:visible`. A direct X11 capture of the resulting
`Codegeist App` scrcpy window showed the centered application text instead of a
gray surface, while ADB confirmed the resumed activity and running process. The
generated merged Dockerfile passed `docker build --check`; a full image export
was not repeated because the Docker filesystem had only 7.3 GiB free.
