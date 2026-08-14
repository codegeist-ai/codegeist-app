# T002: Show Codegeist Start Screen

- ID: `T002`
- Type: `feature`
- Parent: none
- Status: `solved`

## Goal

Display `codegeist` on the application's initial screen.

## Context

T001 established an intentionally empty Android-only Flutter surface. The first
requested visible application behavior is the Codegeist name on that surface.

## Scope

- Render the exact lowercase text `codegeist` on application startup.
- Center the text in the existing scaffold.
- Update the widget regression test and current-state documentation.

## Non-Goals

- Branding assets, custom typography, colors, animation, or theming.
- Controls, navigation, model behavior, networking, or persistence.

## Acceptance Criteria

- The initial screen contains exactly one `codegeist` text widget.
- The text is centered in the application surface.
- No icon, button, navigation, or other product behavior is introduced.
- `task verify` succeeds.

## Relevant Files Or Areas

- `lib/main.dart`
- `test/widget_test.dart`
- `README.md`
- `INDEX.md`

## Implementation Hints

- Keep the existing `MaterialApp` and `Scaffold`; add only the requested body.

## Verification

```bash
task verify
```

## Dependencies

- The Flutter and Android baseline established by T001.

## Open Questions

- None.

## Implementation Notes

Implemented the start screen as a constant `Center` containing the exact text
`codegeist` in the existing scaffold. The widget regression test verifies one
text widget, its value and centered ancestor, and the continued absence of
icons, buttons, and the debug banner.

`task verify` completed successfully. `task android:visible` then installed and
launched the APK with `MainActivity` resumed; Android's UI hierarchy exposed the
centered `codegeist` semantics node on the running 1080 by 2400 display.
