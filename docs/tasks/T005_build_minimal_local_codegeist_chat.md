# T005: Build Minimal Local Codegeist Chat

- ID: `T005`
- Type: `feature`
- Parent: none
- Status: `solved`

## Goal

Let an Android user explicitly download the published Codegeist GGUF and use it
in a minimal, fully local text chat.

## Context

Before this task, the application displayed only the reviewed Codegeist logo.
The public `codegeist/codegeist-llm` repository contains a complete merged
Qwen3-1.7B `Q4_K_M` GGUF suitable for local llama.cpp inference. This first chat
iteration proves the smallest useful product path without introducing a server,
account, settings surface, or persistent conversation storage.

The selected baseline is CPU inference on Android ARM64. Android x64 remains in
the build for the repository's emulator workflows and has completed the full
model download and inference path. No ARM64 device is currently connected, so
physical-device inference is an explicit residual verification gap rather than
a completion requirement for this task.

## Scope

- Add the minimal Flutter dependencies needed for local GGUF inference and
  application-private model storage.
- Package only the llama.cpp runtime family and CPU backend for Android ARM64
  and Android x64.
- Add the Android internet permission required for the public model download.
- Preserve the reviewed Codegeist horizontal logo from the pinned Design
  revision as the shared identity on the model-load and chat surfaces.
- Show an explicit model-load action before chat becomes available; do not
  start the 1.11 GB download automatically.
- Download the pinned Codegeist GGUF into application-private storage, report
  progress, resume interrupted downloads, reuse the cached file, and verify its
  published SHA-256 digest.
- Load the model with a memory-conscious CPU configuration and non-thinking
  generation defaults.
- Provide one in-memory conversation with a scrollable transcript, text input,
  send action, and streamed assistant output.
- Prevent overlapping model loads and generations, expose concise retryable
  failures, and release native resources when the screen is disposed.
- Keep the application implementation in `lib/main.dart` unless a concrete
  implementation constraint requires another source file.
- Update tests and current-state documentation for the new behavior.
- Refresh the README demonstration with the verified prompt and local response.

## Non-Goals

- Vulkan, OpenCL, GPU offload, or performance tuning beyond the CPU baseline.
- A remote inference API, authentication, telemetry, or Hugging Face token.
- Multiple models, file picking, model settings, or an in-app model-delete
  action.
- Persistent chat history, saved inference state, multiple conversations, or
  conversation editing.
- Markdown rendering, syntax highlighting, attachments, tools, speech, or
  multimodal input.
- Background download or inference that survives application backgrounding.
- Bundling model weights in the repository or APK.
- Creating a competing logo, application-wide design system, custom icon set,
  font family, or visual language beyond the approved brand asset.
- Establishing production quality, general coding ability, safety, or broad
  model capability beyond the published experimental artifact.

## Acceptance Criteria

- The initial screen identifies Codegeist, states the approximate model size,
  and exposes a user-triggered model-load action.
- The model-load and chat states render the approved horizontal logo from
  `codegeist-design` commit `132c2ececd20244f08822e8f5738ac946dea32d9`
  with accessible `codegeist` semantics.
- Starting model loading resolves this exact public artifact:
  `codegeist/codegeist-llm` commit
  `ce073afd34b725825b19089cec1a9e7b884b2fbe`, file
  `gguf/codegeist-llm-Q4_K_M.gguf`.
- The expected model size is `1107408672` bytes and the required SHA-256 is
  `be7824de2fc34955d640e30e41e92dd66206e86ab7fe027084015a9b7da44fce`.
- Model bytes remain in application-private storage, interrupted downloads are
  resumable, and later model loads reuse the verified cached file.
- Loading uses CPU inference with GPU layers disabled and a context no larger
  than 2048 tokens for the baseline.
- Once the model is ready, the user can submit non-empty text and see a user
  message followed by incrementally streamed assistant text.
- Generation uses the GGUF's embedded Qwen chat template, disables thinking,
  and caps each response at 256 generated tokens.
- Model loading and generation expose visible busy and failure states without
  allowing duplicate concurrent actions.
- Leaving the screen cancels active generation and disposes the inference
  engine.
- Widget tests cover the lightweight initial contract without downloading a
  model or loading native inference libraries.
- The existing Android smoke test still verifies the launched application
  without triggering the model download.
- The README demonstration shows a real local prompt and assistant response
  while raw recordings and model weights remain outside Git.
- `task verify` and `task smoke` succeed.

## Relevant Files Or Areas

- `pubspec.yaml`
- `pubspec.lock`
- `assets/brand/codegeist-logo-horizontal-light.svg`
- `assets/brand/README.md`
- `lib/main.dart`
- `test/widget_test.dart`
- `android/app/src/main/AndroidManifest.xml`
- `Taskfile.yml`
- `scripts/android-avd.sh`
- `scripts/android-smoke.sh`
- `README.md`
- `docs/assets/codegeist-smoke.gif`
- `INDEX.md`
- `docs/tasks/README.md`

## Implementation Hints

- Use `llamadart` `0.8.19` with `path_provider`; do not introduce state
  management, routing, HTTP, or chat UI packages for this surface.
- Use `flutter_svg` for the existing app-local logo export; do not redraw,
  recolor, or derive another logo inside the application.
- Keep the logo copy byte-identical to
  `assets/codegeist-ai/logos/svg/logo-horizontal-light.svg` from Design commit
  `132c2ececd20244f08822e8f5738ac946dea32d9` and retain its provenance record.
- Configure `llamadart_native_runtimes` for `llama_cpp` only and configure CPU
  modules for `android-arm64` and `android-x64`. Prefer the compact baseline ARM
  CPU profile to reduce packaged native variants.
- Parse an immutable Hugging Face source such as
  `hf://codegeist/codegeist-llm@ce073afd34b725825b19089cec1a9e7b884b2fbe/gguf/codegeist-llm-Q4_K_M.gguf`.
- Pass the expected SHA-256 and an application-private directory through
  `ModelLoadOptions`; rely on llamadart's existing cache, retry, resume, and
  progress behavior instead of writing a second downloader.
- Use `LlamaEngine`, `LlamaBackend`, and `ChatSession` so the embedded chat
  template and in-memory history do not need application-owned prompt logic.
- A reasonable first load is `ModelParams(contextSize: 2048, gpuLayers: 0)`.
  Keep other tuning at library defaults unless Android CPU verification shows a
  concrete need.
- Keep the first screen cheap to launch so widget tests and `task smoke` do not
  invoke platform channels, native assets, or network requests before the user
  presses the model-load action.

## Verification

```bash
task verify
task smoke
```

Also inspect the built APK to confirm Android ARM64 and x64 llama.cpp CPU
libraries are packaged and no model weights are present. A later manual ARM64
check should download the model, verify that it reaches the ready state, submit
`What is Codegeist?`, and confirm that non-empty assistant text streams without
a process crash; this manual check is not required to mark T005 solved because
no ARM64 device is currently available.

## Dependencies

- The Flutter and Android baseline established by T001 through T004.
- `llamadart` `0.8.19` and its pinned prebuilt llama.cpp native runtime.
- Public network access to GitHub Releases during the first native build.
- Public network access to Hugging Face during the first model load.
- Approximately 1.11 GB for the model plus download and application overhead.
- A 64-bit Android device with at least 4 GB RAM is recommended for later
  physical-device inference verification.
- The explicitly owner-approved app-local Codegeist logo export recorded under
  `assets/brand/README.md`.

## Open Questions

- None.

## Implementation Notes

Implemented the single-screen model loader and local chat in `lib/main.dart`.
The user explicitly starts the immutable Hugging Face download; llamadart stores
it under Android application support storage, resumes partial downloads,
verifies the published SHA-256, and reuses the cache. Loading is fixed to CPU,
2048 context tokens, and non-thinking chat generation capped at 256 tokens.
`ChatSession` owns in-memory history while the UI streams each content delta
into the current assistant bubble. Stable `model_load` and `chat_generation`
logs expose operation starts, completions, and failure types without logging
prompt content.

The resolved runtime dependencies are `llamadart` `0.8.19`, `path_provider`
`2.1.6`, and `flutter_svg` `2.3.0`. Android pins
`path_provider_android` `2.2.20`: its later `2.3.x` JNI implementation requires
an additional API 35 platform, while this project intentionally builds against
its installed API 36 toolchain. The selected implementation still uses the
current project compile SDK and keeps the app-private storage contract.

Both canonical APK entrypoints now target only `android-arm64` and
`android-x64`. APK inspection found the baseline ARMv8 CPU module and x64 CPU
module together with `libllamadart.so` for both ABIs, no `armeabi-v7a` payload,
and no `.gguf` model weights. The approved logo remains the only app asset.

`task verify` completed successfully with static analysis, the lightweight
model-loader widget test, shell validation, and the debug APK build. `task smoke`
then installed and launched the x64 APK on `emulator-5556` and verified
the running process, resumed activity, Codegeist logo semantics, and idle
`Load model` action without starting network work.

The x64 Android emulator completed the 1.11 GB download, checksum promotion,
cached model reload, and CPU generation path. Submitting `What is Codegeist?`
produced a non-empty streamed identity response, and the final UI semantics
contained both the prompt and answer. This manual inference check is separate
from `task smoke`, which intentionally stops at the idle model-load screen.

No physical ARM64 device was available, as accepted in this task. ARM64 runtime
execution remains the only device-level verification gap.
