# My Vibe Island

My Vibe Island is a non-commercial, local-first macOS companion for monitoring
agent sessions from a notch/island surface. It is an independent Swift
implementation with explicit boundaries between the UI, runtime model, shared
protocols, hooks, bridge, setup, and terminal jump handling.

## Status

This project is an active reconstruction and research implementation, not a
finished replacement for any commercial application. The current package
builds the following products:

- `my-vibe-island`: macOS app executable
- `my-vibe-island-bridge`: local bridge executable
- `my-vibe-island-hooks`: hook executable
- `my-vibe-island-setup`: setup executable
- Swift libraries for app, core, shared, hooks, and setup domains

The UI, live session ingestion, notifications, sound controls, terminal/IDE
jump routing, diagnostics, and settings are implemented incrementally. Some
integrations remain platform- or environment-dependent.

## Requirements

- macOS 14 or later
- Xcode 16 or later, or Swift 6.2 toolchain
- A local terminal/agent environment for live integration testing

## Build And Test

```bash
swift build
swift test
```

Build one executable directly:

```bash
swift build --product my-vibe-island
swift build --product my-vibe-island-bridge
swift build --product my-vibe-island-hooks
```

The test suite is fixture-driven and includes core models, bridge/hook
protocols, runtime reducers, AppKit composition, packaging helpers, and
diagnostic redaction behavior.

## Optional Local Reference Data

Reference-only payloads and private runtime captures are intentionally not
included in this repository. The public project builds and installs its own
bridge and hooks. Any local comparison material must remain outside Git and
must be used only when you have the right to access it.

## Architecture

```text
MyVibeIslandApp
        |
        v
MyVibeIslandCore <-> MyVibeIslandShared
        ^                   ^
        |                   |
MyVibeIslandHooks      my-vibe-island-bridge
        ^
        |
my-vibe-island-hooks
```

- **Shared** defines transport-safe identifiers, session and environment
  contracts, and cross-process value types.
- **Core** owns runtime state, session admission, event reduction, display
  models, notifications, sound plans, diagnostics, and jump decisions.
- **Hooks** converts agent lifecycle events into the local bridge protocol.
- **Bridge** receives hook and provider events and publishes normalized runtime
  updates without embedding UI policy.
- **App** renders the island and coordinates AppKit lifecycle, settings,
  notifications, sounds, and jump actions.

See [`docs/architecture/system-architecture.md`](docs/architecture/system-architecture.md)
and [`docs/architecture/bridge-hook-protocol.md`](docs/architecture/bridge-hook-protocol.md)
for the detailed boundaries.

## Privacy And Security

The project is local-first. Diagnostics and exported snapshots are designed to
redact credentials, tokens, authorization values, prompts, transcripts, and
source content. Do not paste real credentials or private conversation data into
fixtures, screenshots, or issue reports.

Before publishing a clone or fork, inspect the complete Git history as well as
the current tree. Research documents may contain local filesystem paths or
screenshots from private sessions even when they do not contain API keys.
Remove or redact those artifacts before making a public repository.

## Scope Boundaries

This project does not implement or distribute:

- license activation, trial gates, checkout, payment, or entitlement bypasses
- proprietary source code, private assets, or commercial service contracts
- commercial telemetry or crash reporting by default

## License

No license has been selected for this repository yet. Until a license file is
added, the source should not be redistributed under an assumed open-source
license.
