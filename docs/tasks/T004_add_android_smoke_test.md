# T004: Add Android Smoke Test

- ID: `T004`
- Type: `test`
- Parent: none
- Status: `solved`

## Goal

Provide one repeatable Android runtime smoke test and generate a reviewable MP4
of the tested application launch.

## Context

Flutter analysis, widget tests, and APK builds verify the project before an AVD
starts, while the existing Android workflow verifies only that the installed app
process exists. A focused smoke test must also prove that the expected activity
is foregrounded and that Android exposes the start-screen text.

## Scope

- Start or reuse the dedicated AVD through the existing headless workflow.
- Verify the expected ADB serial, application process, resumed `MainActivity`,
  and `codegeist` UI semantics.
- Expose the checks as `task smoke`.
- Expose `task smoke:record` to run the checks and record an application restart
  through scrcpy within a six-second capture window.
- Validate that the recording has a video stream and positive duration.
- Keep generated recordings outside Git.
- Derive a compact committed README GIF from the meaningful launch frames.

## Non-Goals

- Pixel-perfect screenshot comparison or visual regression testing.
- User-input automation, navigation, performance measurement, or audio capture.
- Committing raw screenshots or MP4 recordings.

## Acceptance Criteria

- `task smoke` exits successfully only when `emulator-5556` is online,
  `ai.codegeist.app` is running, `.MainActivity` is resumed, and Android's UI
  hierarchy contains `codegeist`.
- Successful non-recording output contains only `emulator-5556` on stdout; logs
  remain on stderr.
- `task smoke:record` produces `.artifacts/codegeist-smoke.mp4` and returns its
  absolute path on stdout.
- `ffprobe` reports a video codec and positive duration for the MP4.
- `.artifacts/` is ignored by Git.
- `docs/assets/codegeist-smoke.gif` shows only the Flutter launch transition and
  final `codegeist` screen and is embedded in the root README.
- `task verify` succeeds.

## Relevant Files Or Areas

- `scripts/android-smoke.sh`
- `scripts/android-avd.sh`
- `Taskfile.yml`
- `.gitignore`
- `README.md`
- `INDEX.md`

## Implementation Hints

- Reuse the established AVD workflow rather than duplicating emulator setup,
  build, install, or boot logic.
- Record without playback or a second window so capture does not depend on X11.

## Verification

```bash
task smoke
task smoke:record
ffprobe .artifacts/codegeist-smoke.mp4
task verify
git --no-pager diff --check
```

## Dependencies

- T001 Android AVD workflow.
- T002 start-screen text.
- T003 pinned scrcpy installation.
- `ffprobe` from the shared devcontainer's FFmpeg installation.

## Open Questions

- None.

## Implementation Notes

`scripts/android-smoke.sh` delegates setup, build, installation, and launch to
the established headless AVD workflow. It then checks the selected device,
application process, resumed activity, and `codegeist` semantics node directly
through ADB. Stable operation logs go to stderr, while stdout returns only the
serial or recording path.

Recording mode uses scrcpy without audio, control, playback, or a window. It
starts a six-second capture, restarts the application, repeats the runtime
checks, and validates the resulting video stream and duration with `ffprobe`.
The generated artifact is replaced only on an explicit recording run and stays
under the ignored `.artifacts/` directory.

Verification completed with `task smoke`, `task smoke:record`, `ffprobe`, frame
inspection, and the stdout contract checks. The generated H.264 MP4 is 1080 by
2400 pixels, 4.81 seconds long, and 241293 bytes. Captured frames show the
Flutter launch screen followed by the centered `codegeist` application screen.

The README GIF retains only that meaningful launch sequence. It uses a
palette-optimized 10 FPS conversion at 320 by 711 pixels, contains 24 frames,
loops after 2.4 seconds, and is 44362 bytes. The source MP4 remains ignored while
the small curated derivative is committed under `docs/assets/`.
