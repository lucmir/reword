# CLAUDE.md

Guidance for Claude Code (and humans) working in this repository.

## What Reword is

Reword is a native macOS menu-bar app that rewrites the currently selected text
**anywhere on screen** using the Anthropic API. The user selects text in any app,
presses a global hotkey (**⇧⌘R**), and a floating panel shows the AI-rewritten
version. Clicking **Apply** replaces the original selection in place. Rewrite
prompts ("presets") are user-editable in Settings.

- Menu-bar-only (`LSUIElement`), no Dock icon, no background daemon.
- Bring-your-own Anthropic API key, stored in the macOS Keychain (never on disk).
- Ships with five presets (Improve writing, Make formal, Make casual, Fix grammar, Shorten).

## Repository layout

This is a **two-part build**: a pure-Swift SwiftPM library plus an XcodeGen-generated app target.

```
Package.swift                 # RewordCore library + test target (swift-tools 5.9, macOS 14)
Sources/RewordCore/           # Pure Swift, ZERO AppKit — unit-tested business logic
  Preset.swift                # Preset model: {id, name, prompt, isDefault}
  PromptStore.swift           # ObservableObject; JSON persistence + seed presets
  AIProvider.swift            # protocol AIProvider + enum AIError (.userMessage)
  AnthropicProvider.swift     # URLSession call to /v1/messages (no SDK)
  TextCapture.swift           # TextCaptureService: capture/replace orchestration + fallback logic
  RewordCore.swift            # (umbrella/misc)
Tests/RewordCoreTests/        # 25 tests: PromptStore, AnthropicProvider (mocked URLSession),
                              #   TextCaptureService (fake strategies), SmokeTests
App/                          # The macOS app — OS-coupled code, NOT built by SwiftPM
  project.yml                 # XcodeGen spec; generates Reword.xcodeproj (gitignored)
  Resources/AppIcon.icns
  Sources/
    RewordApp.swift           # @main App + AppServices.shared DI singleton
    HotkeyManager.swift       # KeyboardShortcuts global hotkey (⇧⌘R)
    TransformCoordinator.swift# The pipeline: capture → transform → preview → apply
    AccessibilityCaptureStrategy.swift  # Real AX read/write (AXUIElement)
    ClipboardCaptureStrategy.swift      # Real clipboard-simulation read/write (CGEvent ⌘C/⌘V)
    KeychainSecretStore.swift # Security framework wrapper for the API key
    OnboardingWindow.swift    # First-run Accessibility-permission prompt
    PreviewPanel/
      PanelViewModel.swift    # @Published state + action callbacks
      PreviewPanelController.swift  # Non-activating NSPanel lifecycle, Esc monitors, resize
      PreviewPanelView.swift  # SwiftUI panel body
    Settings/
      SettingsView.swift      # TabView: Prompts / General / API
      PromptsSettingsView.swift  # Preset list + editor
      GeneralSettingsView.swift  # Model picker (UserDefaults "model")
      APISettingsView.swift   # API-key field + "Test connection"
docs/
  assets/                     # README screenshots + demo GIF
  superpowers/specs/          # Design spec
  superpowers/plans/          # Implementation plan
.github/workflows/ci.yml      # runs-on: macos-15 — swift test + full app build
```

## Build & test

**Core library tests** (fast, no Xcode project needed):

```bash
swift test                    # from repo root — runs the 25 RewordCore tests
```

**Full app build** (requires Xcode 16+ and XcodeGen):

```bash
cd App
xcodegen generate             # regenerates Reword.xcodeproj from project.yml (project is gitignored)
xcodebuild -project Reword.xcodeproj -scheme Reword \
  -configuration Release -derivedDataPath build build
```

**Install the built app:**

```bash
ditto App/build/Build/Products/Release/Reword.app /Applications/Reword.app
open /Applications/Reword.app
```

CI (`.github/workflows/ci.yml`) runs `swift test` and a Debug app build on `macos-15`.
It **must** run on `macos-15` — older runners ship Xcode 15.4, which cannot read
the generated project's format (77).

## Key conventions & invariants

- **`RewordCore` must never import AppKit/SwiftUI.** It is the testable core; all
  OS-coupled code lives in `App/Sources`. Adding an AppKit import here breaks the
  separation and the `swift test` build. New business logic goes in `RewordCore`
  with tests; new OS glue goes in `App`.
- **The Xcode project is generated, not committed.** Never hand-edit
  `Reword.xcodeproj`; change `App/project.yml` and re-run `xcodegen generate`.
- **The API key lives only in the Keychain.** Never write it to UserDefaults, JSON,
  logs, or source. Service `com.lucmir.reword`, account `anthropic-api-key`.
  To set it manually:
  `security add-generic-password -s com.lucmir.reword -a anthropic-api-key -w "<key>"`
- **Bundle identifier:** `com.lucmir.reword`. **Model default:** `claude-opus-4-8`
  (options include `claude-sonnet-5`, `claude-haiku-4-5`), read from
  `UserDefaults "model"`.
- **Presets** persist to `~/Library/Application Support/Reword/presets.json`.
  `PromptStore.update(_:)` deliberately preserves the stored `isDefault` flag so
  editing a preset can't accidentally clear/steal the default; use `setDefault(id:)`
  to change it. There is always at least one preset and always exactly one default.
- **Dependency injection** goes through `AppServices.shared` (`App/Sources/RewordApp.swift`).
  Everything OS-facing is constructed there so the coordinator/providers stay testable.

## The transform pipeline (how it actually works)

`TransformCoordinator.run()` (`App/Sources/TransformCoordinator.swift`) is the spine:

1. **Capture** the selection via `TextCaptureService.captureSelection()`:
   tries the Accessibility API first (`kAXSelectedTextAttribute`), falls back to
   clipboard simulation (snapshot pasteboard → send ⌘C → read → restore) if AX
   returns empty/fails. A `permissionDenied` from AX is rethrown (no fallback) so
   the user gets the Accessibility prompt instead of a silent clipboard grab.
2. **Transform** via `AnthropicProvider.transform(text:prompt:)` — the selected
   text is the user message, the preset prompt is the `system` prompt. 30s timeout,
   `max_tokens: 16000`. Runs in a cancellable `Task`; `run()`/`transform()` cancel
   any in-flight task first.
3. **Preview** in the non-activating `NSPanel`. It must **never steal focus** — the
   original app keeps its selection alive so the in-place replace works. Because the
   panel is focusless, Esc is handled via `NSEvent` local+global monitors, not a
   normal key handler.
4. **Apply** via `TextCaptureService.replaceSelection(with:using:)` using the same
   method that captured. For the accessibility path it writes, then **reads the
   selection back** — Chromium/Electron apps (Slack, Chrome, Gmail-in-Chrome) report
   a successful AX write without applying it, so if the selection is unchanged it
   pastes instead. Any AX failure also falls back to paste.

**Clipboard fallback is careful:** it snapshots the *entire* pasteboard (all types,
not just string), guards restores with `changeCount` so it won't clobber something
you copied in the meantime, and delays the post-paste restore ~0.3s so the paste
lands first.

## Compatibility notes

Verified by hand (see README table). Terminals don't expose an editable text
selection, so Apply there pastes at the cursor rather than replacing. This is a
known limitation, not a bug.

## When making changes

- Adding/altering core logic → put it in `RewordCore`, add a test, run `swift test`.
- Touching capture/replace behavior → this is the fragile, app-specific part.
  Test against a Chromium app (Slack) *and* a native one (TextEdit); the two paths
  behave differently.
- Changing the app's build config, entitlements, Info.plist, packages, or icon →
  edit `App/project.yml`, then `xcodegen generate`.
- Before pushing, run `swift test` locally; CI will also do the full app build.
- **Demo asset caching:** GitHub's camo CDN caches README images by URL. If you
  update a screenshot/GIF in place, the old one may still show. Rename the file to
  bust the cache (this is why assets are `demo-flow.gif` / `rewrite-demo.png`).
