# Codegeist App

Codegeist App is the future Android client for private, local Codegeist model
inference.

## Current State

This repository contains only its initial documentation, license, and shared
workspace setup. The Flutter application, Android platform project, model
download flow, inference runtime, user interface, tests, and emulator workflow
will be implemented in a separate task.

## Hosting

The private Gitea repository at
`https://git.codegeist.ai/codegeist/codegeist-app` is the primary write target.
The public GitHub repository at
`https://github.com/codegeist-ai/codegeist-app` is a push mirror of Git refs.

The mirror does not synchronize issues, pull requests, secrets, permissions,
Actions state, or other platform-specific data. Treat every committed ref as
public and never commit credentials, private prompts, restricted model
artifacts, or other non-public material.

## Workspace Kits

`.devcontainer/` and `.opencode/` are Git submodules that track the `release`
branches of the shared Codegeist development and agent kits. Initialize them
from this repository with:

```bash
git submodule update --init .devcontainer .opencode
```

Project-specific implementation and development-environment extensions remain
deferred until the application task starts.

## License

Codegeist-authored source and documentation in this repository are licensed
under the [Zero-Clause BSD License](LICENSE). Future third-party runtimes and
model artifacts retain their own licenses and notice requirements.
