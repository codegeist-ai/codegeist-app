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
is foregrounded and that Android exposes the start-screen semantics.

## Scope

- Start or reuse the dedicated AVD through the existing headless workflow.
- Verify the expected ADB serial, application process, resumed `MainActivity`,
  Codegeist logo semantics, and idle model-load action.
- Expose the checks as `task smoke`.
- Expose `task smoke:record` to run the checks and record an application restart
  through scrcpy within a six-second capture window.
- Validate that the recording has a video stream and positive duration.
- Keep generated recordings outside Git.
- Keep a compact committed README GIF that shows the current verified app
  behavior while raw captures remain outside Git.

## Non-Goals

- Pixel-perfect screenshot comparison or visual regression testing.
- User-input automation in the smoke command, navigation, performance
  measurement, or audio capture.
- Committing raw screenshots or MP4 recordings.

## Acceptance Criteria

- `task smoke` exits successfully only when `emulator-5556` is online,
  `ai.codegeist.app` is running, `.MainActivity` is resumed, and Android's UI
  hierarchy contains `codegeist` and `Load model` without starting the model
  download.
- Successful non-recording output contains only `emulator-5556` on stdout; logs
  remain on stderr.
- `task smoke:record` produces `.artifacts/codegeist-smoke.mp4` and returns its
  absolute path on stdout.
- `ffprobe` reports a video codec and positive duration for the MP4.
- `.artifacts/` is ignored by Git.
- `docs/assets/codegeist-smoke.gif` shows the model-download prompt, model
  preparation, verified local chat prompt, and assistant response and is
  embedded in the root README.
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
- T005 local model-load screen and its lightweight idle launch contract.
- `ffprobe` from the shared devcontainer's FFmpeg installation.

## Open Questions

- None.

## Implementation Notes

`scripts/android-smoke.sh` delegates setup, build, installation, and launch to
the established headless AVD workflow. It then checks the selected device,
application process, resumed activity, `codegeist` semantics node, and
`Load model` action directly through ADB. Stable operation logs go to stderr,
while stdout returns only the serial or recording path.

Recording mode uses scrcpy without audio, control, playback, or a window. It
starts a six-second capture, restarts the application, repeats the runtime
checks, and validates the resulting video stream and duration with `ffprobe`.
The generated artifact is replaced only on an explicit recording run and stays
under the ignored `.artifacts/` directory.

The automated smoke recording remains limited to the idle model-load screen.
After T005 verified real local inference, the committed README GIF was refreshed
separately from reviewed emulator captures without adding chat automation to the
smoke command.

Verification completed with `task smoke`, `task smoke:record`, `ffprobe`, frame
inspection, and the stdout contract checks. The refreshed H.264 MP4 is 1080 by
2400 pixels, 5.105 seconds long, and 426545 bytes. Captured frames show the
Flutter launch screen followed by the Codegeist local model-load screen.

The README GIF now shows the model-download prompt, cached-model preparation,
loaded chat, prompt entry and submission, and the verified assistant response.
It uses a palette-optimized 8 FPS conversion at 320 by 711 pixels, contains 101
frames, loops after 12.62 seconds, and is 160463 bytes. Source MP4s and
inspection frames remain ignored while the curated derivative is committed
under `docs/assets/`.
