# Tasks

This directory stores focused implementation tasks for Codegeist App.

## Workflow

- Create top-level tasks as `TNNN_<slug>.md` from `template.md`.
- Use `specified` when a task is ready for implementation, `blocked` when a
  required decision or dependency is missing, and `solved` after its
  verification passes.
- Keep acceptance criteria observable and verification commands explicit.
- Move a task into `TNNN_<slug>/task.md` only if it gains child tasks under a
  matching `tasks/` directory.

## Current Tasks

- `T001_bootstrap_minimal_flutter_android_app.md` - create the smallest Android-
  only Flutter app and run it in a reproducible Android Virtual Device.
- `T002_show_codegeist_start_screen.md` - display the Codegeist name on the
  application's start screen.
- `T003_use_scrcpy_for_visible_android.md` - mirror the visible Android workflow
  through scrcpy instead of the native emulator window.
- `T004_add_android_smoke_test.md` - verify the running Android app and record a
  local MP4 of its launch.
- `T005_build_minimal_local_codegeist_chat.md` - download the pinned Codegeist
  GGUF and provide a minimal local CPU chat on Android.
