# Repository Index

Navigation map for the minimal Codegeist App repository bootstrap.

## When To Read This

- Read this before adding application code, Android configuration, model
  artifacts, inference runtimes, or project automation.

## Directory Map

- `README.md` - future purpose, current bootstrap boundary, hosting, and shared
  workspace setup.
- `LICENSE` - 0BSD terms for Codegeist-authored repository content.
- `.gitignore` - machine-local workspace files excluded from Git.
- `.gitmodules` - shared-kit sources and release-branch tracking.
- `.devcontainer/` - shared development environment on its `release` branch.
- `.opencode/` - shared OpenCode agent kit on its `release` branch.

## Known Directory Indexes

- `INDEX.md` - this repository-root index.

## Key Workflows

- Initialize shared kits with `git submodule update --init .devcontainer
  .opencode`.
- Specify and review the application task before adding Flutter, Android, model,
  runtime, test, or emulator files.

## Update Triggers

- Update this index when top-level files, directories, or entrypoints change.

## Agent Notes

- Treat every committed ref as public because GitHub mirrors Gitea Git refs.
- Do not add model weights, generated artifacts, credentials, or placeholder
  application code without an implementation task.
