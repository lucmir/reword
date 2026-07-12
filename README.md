# Reword

Fix, polish, or rewrite any selected text on macOS with a hotkey — powered by Claude, with fully customizable prompts.

Select text in any app (Slack, Mail, your browser, a terminal), press **⇧⌘R**, review the AI-rewritten version in a floating panel, and apply it in place.

<!-- TODO after first release: demo GIF here -->

## Features

- **Works everywhere** — hybrid capture: macOS Accessibility API first, clipboard simulation fallback for apps with poor AX support (e.g. Electron apps)
- **Preview before you apply** — nothing is replaced until you click Apply; Copy and Retry available
- **Custom prompt presets** — ships with Improve / Formal / Casual / Fix grammar / Shorten; add and edit your own in Settings
- **Bring your own API key** — stored in the macOS Keychain, never on disk
- **Menu-bar native** — Swift + SwiftUI, no Electron, no Dock icon

## Install

Build from source (requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)):

```bash
git clone https://github.com/lucmir/reword.git
cd reword/App
xcodegen generate
xcodebuild -project Reword.xcodeproj -scheme Reword -configuration Release -derivedDataPath build build
open build/Build/Products/Release/Reword.app
```

On first launch, grant Accessibility permission and add your Anthropic API key in Settings → API.

## Architecture

- **`RewordCore`** (SwiftPM library, fully unit-tested): preset model + JSON persistence, Anthropic Messages API provider behind an `AIProvider` protocol, and the hybrid capture orchestrator (`TextCaptureService`) that tries Accessibility first and falls back to clipboard simulation.
- **App target** (XcodeGen): menu bar UI, global hotkey ([KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)), real AX/clipboard strategies, floating `NSPanel` preview, SwiftUI settings, Keychain storage.

Run the tests with `swift test`.

## Manual test matrix

Real Accessibility behavior varies by app. Verified by hand per release:

| App | Capture | Replace |
|---|---|---|
| TextEdit | ☐ | ☐ |
| Notes | ☐ | ☐ |
| Safari (text field) | ☐ | ☐ |
| Chrome (text field) | ☐ | ☐ |
| Slack | ☐ | ☐ |
| Mail | ☐ | ☐ |
| Terminal | ☐ | ☐ (copy-only expected) |

## License

MIT
