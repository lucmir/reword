# Reword — Design Spec

**Date:** 2026-07-11
**Status:** Approved

## What it is

Reword is a native macOS menu bar app that transforms selected text anywhere on the system using AI. Select text in any app (Slack, Mail, a browser, a terminal), press a global hotkey, review the AI-rewritten version in a floating preview panel, and apply it in-place. Prompts are fully user-customizable presets.

Primary goals:
1. A genuinely useful daily tool for the author (frequent "improve this text" workflows).
2. A portfolio-quality open-source project demonstrating native macOS platform skills.

## Decisions made

| Decision | Choice |
|---|---|
| Stack | Native Swift/SwiftUI menu bar app, macOS 14+ |
| Interaction | Global hotkey → floating preview panel → Apply/Copy/Retry |
| Prompts | Multiple named presets, each editable, optional per-preset hotkey, one default |
| AI backend | Bring-your-own API key, Anthropic Messages API first, provider protocol for future backends |
| Text capture | Hybrid: Accessibility API first, clipboard (⌘C/⌘V) simulation fallback |
| V1 scope | Menu bar icon + settings window only. No history, no streaming, no launch-at-login/auto-update (v1.1 candidates) |

## Architecture

A menu-bar-only app (`LSUIElement = true`, no Dock icon). Six components with clear boundaries:

### 1. HotkeyManager
Registers global shortcuts using the `KeyboardShortcuts` SwiftPM package (sindresorhus). One shortcut for the default preset; each preset may optionally bind its own. The package also provides the shortcut-recorder settings UI.

### 2. TextCaptureService
The hybrid capture/replace engine behind a single protocol:

- `captureSelection() async throws -> CapturedText`
  1. Try Accessibility: focused `AXUIElement`, read `kAXSelectedTextAttribute`.
  2. Fallback: save clipboard contents, synthesize ⌘C via CGEvent, read clipboard, restore original clipboard.
- `replaceSelection(with: String) async throws`
  1. Try Accessibility: write `kAXSelectedTextAttribute`.
  2. Fallback: put replacement on clipboard, synthesize ⌘V, restore original clipboard afterwards.

The capture result remembers which strategy succeeded so replacement prefers the same path. AX and clipboard mechanics live behind small strategy types so the orchestration is unit-testable with fakes.

### 3. PromptStore
Preset model: `id`, `name`, `promptTemplate`, `optional hotkey`, `isDefault`. Persisted as JSON at `~/Library/Application Support/Reword/presets.json`. Ships with sensible defaults ("Improve writing", "Make formal", "Make casual", "Fix grammar", "Shorten"). The Anthropic API key is stored in the macOS Keychain only — never in the JSON file.

### 4. AIClient
```swift
protocol AIProvider {
    func transform(text: String, prompt: String) async throws -> String
}
```
V1 ships `AnthropicProvider`: direct `URLSession` calls to the Anthropic Messages API (no SDK dependency). The preset's prompt is the system prompt; the captured text is the user message. Model configurable in settings (sensible default, e.g. a fast/cheap current model). 30s timeout. Errors mapped to a typed `AIError` (noKey, auth, rateLimit, network, server) for user-facing messages.

### 5. PreviewPanel
Floating, non-activating `NSPanel` hosting a SwiftUI view, positioned near the mouse/selection. States:
- **Loading** — appears immediately on hotkey so the app feels instant.
- **Result** — rewritten text, buttons: **Apply** (replace in-place, close, return focus), **Copy**, **Retry**, plus a preset dropdown to re-run with a different prompt.
- **Error** — human-readable message with contextual action (Retry, or Open Settings).

Esc dismisses. Panel never steals focus from the source app until the user interacts with it.

### 6. SettingsWindow
SwiftUI settings with tabs:
- **Prompts** — CRUD + reorder presets, set default, per-preset hotkey recorder.
- **General** — main hotkey, model picker.
- **API** — key field (writes to Keychain), "Test connection" button.

### Onboarding
First launch: a short window explaining the Accessibility permission requirement with a button deep-linking to System Settings → Privacy & Security → Accessibility, and a live indicator that flips when permission is granted.

## Data flow (happy path)

1. User selects text, presses hotkey.
2. `TextCaptureService.captureSelection()` grabs the text.
3. PreviewPanel opens in loading state.
4. `AnthropicProvider.transform()` runs with the active preset.
5. Result renders in the panel.
6. **Apply** → `replaceSelection(with:)` → panel closes → focus returns to source app.

## Error handling

| Case | Behavior |
|---|---|
| No text selected | Panel shows "Select some text first", auto-dismisses. Never fails silently. |
| No Accessibility permission | Panel explains + deep-link to System Settings. |
| Missing API key / auth failure | Panel message + button opening Settings → API tab. |
| Network / rate limit / server error | Readable message + Retry button. |
| Any clipboard-fallback path | User's original clipboard is always restored, including on error (`defer`). |

## Testing

- **Unit tests:** `PromptStore` persistence round-trip; `AnthropicProvider` via mocked `URLProtocol` (request shape, header auth, error mapping); capture/replace orchestration with fake AX/clipboard strategies (fallback order, clipboard restoration on error).
- **Manual test matrix** (documented in README, since real AX behavior is app-dependent): Slack, Mail, Chrome, Safari, Notes, Terminal — capture and replace verified in each.

## Repo & distribution

- Standalone repo `reword`, MIT license.
- Xcode project + SwiftPM dependencies (`KeyboardShortcuts`).
- GitHub Actions CI: build + unit tests on macOS runner.
- README: animated GIF demo, feature list, architecture overview, manual test matrix, setup guide.
- Distribution: GitHub Releases. Signed/notarized `.dmg` if an Apple Developer account is available; otherwise build-from-source instructions. Decided at ship time; no code impact.

## Out of scope for v1 (candidates for v1.1+)

- Transformation history
- Streaming responses into the panel
- Launch at login, Sparkle auto-update
- Additional providers (OpenAI, Ollama) — protocol seam exists
- Per-app default presets
