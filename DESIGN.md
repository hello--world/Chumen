# Design

## Source of truth
- Status: Active
- Last refreshed: 2026-07-04
- Primary product surfaces: Native macOS Chumen app and its menu bar controller.
- Evidence reviewed: `Sources/ChumenMacApp/ContentView.swift`, `Sources/ChumenMacApp/AppModel.swift`, `Sources/ChumenMacApp/L10n.swift`, `README.md`, `docs/security-model.md`, user screenshots of Chumen, macOS Settings, and Shortcuts.
- Implementation spec: `docs/ui-design-system.md` is the detailed UI contract for colors, layout, typography, first-run setup, search, dashboard, list, and AI assistant surfaces. `docs/security-model.md` is the source of truth for config encryption, PIN, app lock, Keychain, runtime plaintext, logging, and AI review boundaries.

## Brand
- Personality: quiet, native, technical, reliable.
- Trust signals: clear state, reversible controls, direct core/API feedback, readable Chinese copy.
- Avoid: web-dashboard card stacks, heavy gray banners, strong shadows, decorative gradients, theme-heavy styling, or copied macOS Settings layout.

## Product goals
- Goals: make core status, proxy state, TUN, traffic, and operations easy to scan and control.
- Non-goals: theme customization and decorative marketing UI.
- Success signals: the app feels like a small macOS utility, not a web page embedded in a window.

## Personas and jobs
- Primary personas: macOS users running mihomo locally.
- User jobs: start/stop the core, inspect status, switch policies, manage providers, diagnose connections, and tune runtime settings.
- Key contexts of use: menu bar quick checks, repeated dashboard scanning, and occasional advanced configuration.

## Information architecture
- Primary navigation: top tab bar.
- Core routes/screens: dashboard, profiles, proxies, providers, connections, rules, core, core tools, logs, settings.
- Content hierarchy: current runtime state first, then global search, then actions, metrics, and lists; the header is a single compact row with app/running state on the left, a modest-width search launcher, and a persistent status strip for API, system proxy, mode, speed, traffic, and TUN. Activating search opens a larger Spotlight-style top search layer with a near full-width input and results panel; the active layer fully covers the header/search launcher so no duplicate search field or header status leaks through. Search results include category scopes and rank settings/core matches before rules, connections, logs, or provider data. Header status may scroll horizontally in narrow windows, but it must not disappear as a width workaround. A bottom-right assistant affordance opens a compact floating panel; the primary AI path is local Ollama at `http://127.0.0.1:11434/v1`, which needs no Key, while remote OpenAI-compatible endpoints require a saved Key. Without a usable model endpoint it behaves as a local search surface. The `内核` tab owns mihomo/runtime configuration and keeps a fixed left quick navigation, while the `设置` tab owns Chumen preferences such as menu bar, language, system proxy behavior, and local files; settings edits persist automatically, while applying saved core changes to a running core remains an explicit action.

## Design principles
- Principle 1: use low-contrast grouped surfaces with hairline borders instead of prominent floating cards.
- Principle 2: make state readable without oversized blocks or loud color.
- Principle 3: use system-native SwiftUI/AppKit controls and semantic colors first; add custom color only as a small identity or action accent.
- Tradeoffs: functional density is more important than decorative whitespace.

## Visual language
- Color: system adaptive backgrounds, subtle separators, green only for active/running, blue only for primary action.
- Typography: native system type, semibold for state values, captions for labels.
- Spacing/layout rhythm: compact utility spacing with grouped rows and consistent 8 px radius.
- Shape/radius/elevation: max 8 px radius for cards/panels; no heavy shadows on routine dashboard surfaces.
- Motion: system-default only.
- Imagery/iconography: SF Symbols and the app icon; the menu bar status icon uses tiny app-icon-style white door variants where a closed door means traffic is not being captured, a half-open door means system proxy is active, and a fully open white door means effective TUN routing is active. No copied system app iconography beyond platform conventions.

## Components
- Existing components to reuse: header, command panel, metric tile, settings form, tab navigation.
- New/changed components: centered global search field with dropdown results, compact header status pills, native grouped dashboard surfaces, localized status error copy, `内核` quick navigation sidebar, separate `设置` form, first-run security setup panel with muted neutral grouping and a distinct app-lock toggle, review-first AI assistant panel, and closed/half-open/open door variants for the menu bar status icon.
- Variants and states: running/stopped, API reachable/unreachable, proxy on/off, TUN on/off, empty metrics, local Ollama ready, remote AI key missing/search-only, AI pending diff review, menu bar closed/half-open/open door network capture state.
- Token/component ownership: `ChumenStyle` in `ContentView.swift`.

## Accessibility
- Target standard: clear contrast and readable text at default macOS sizes.
- Keyboard/focus behavior: use system controls so focus rings and shortcuts remain native; global search should accept Return to open the first result, close on outside click or Esc, debounce result generation, avoid full search during single-letter IME composition, scan proxy/rule/connection/log snapshots off the main thread, let users constrain results by scope, and render its result panel as a top-level overlay that does not participate in header layout. The assistant input must not apply changes on Return; it either searches locally when no AI key is configured or sends a request that only creates pending diff review items.
- Contrast/readability: avoid low-contrast text over material blur.
- Screen-reader semantics: keep labels on buttons and status values.
- Reduced motion and sensory considerations: avoid nonessential animation.

## Responsive behavior
- Supported breakpoints/devices: resizable macOS app window.
- Layout adaptations: dashboard metrics wrap via adaptive grid; header search and status information stay in one row under window resizing, with horizontal status scrolling preferred over hidden status chips.
- Touch/hover differences: pointer-first macOS interactions.

## Interaction states
- Loading: show existing status text and last refresh values.
- Empty: use dash placeholders.
- Error: localize common connectivity failures and keep technical details in logs/tools when needed.
- Success: concise status text.
- Disabled: use native disabled controls.
- Offline/slow network, if applicable: API status should indicate unreachable controller without visually dominating the dashboard.
- AI draft review: every AI-suggested operation is a temporary proposed change with a git-like diff. The user must explicitly apply each item; no model response may directly mutate settings, import profiles, toggle proxy/TUN, or reload runtime config.

## Security And Privacy Model
- Source of truth: `docs/security-model.md`.
- Configuration is encrypted by default with the mihomo age path; Chumen should not create a parallel long-term config encryption scheme.
- PIN has two independent meanings: age private-key protection and optional application lock. PIN protection is on by default; application lock is off by default.
- Default startup should auto-unlock the PIN-protected age key using Chumen's local wrapping key, so the app behaves normally unless app lock is enabled.
- Enabling app lock must remove the auto-unlock path and require PIN on launch. Disabling app lock may recreate auto-unlock only from an already unlocked age key.
- Do not explain or implement app lock as a side effect of enabling PIN. UI copy must make it clear that app lock is a separate switch.
- Default age private-key storage is local file; Keychain is optional.
- Do not use a fixed salt as the default decrypt mechanism. PIN derivation uses a random per-vault salt; default auto-unlock uses a random local wrapping key.
- Fixed Application Support runtime config may exist only as protected data when config protection is enabled. If a future path needs unavoidable plaintext runtime material, write it to a random temporary session directory and clean it with an explicit cleanup owner.
- Every user-visible security/runtime notification must also be logged with sanitized context; never log PINs, API keys, controller secrets, age private keys, decrypted profile content, or credential-bearing subscription URLs.

## Content voice
- Tone: concise utility language.
- Terminology: use "core", "API", "TUN", "DNS", "Provider" consistently with the product.
- Microcopy rules: Chinese UI should not leak common Foundation networking errors in English.

## Implementation constraints
- Framework/styling system: SwiftUI/AppKit native controls.
- Design-token constraints: keep style tokens in `ChumenStyle`; no new theming layer.
- UI contract constraints: every UI change must check `docs/ui-design-system.md` first; if the implementation needs an exception, update the document or add a local code intent note explaining why.
- Performance constraints: dashboard updates must remain cheap during traffic/connection streams; assistant search uses the same debounced/off-main-thread snapshot search as global search.
- Compatibility constraints: macOS native Swift Package app.
- Security constraints: AI API keys are stored in Keychain, not in `settings.json`; local Ollama does not require a key; model calls use user-configured OpenAI-compatible endpoints.
- Test/screenshot expectations: run Swift build/tests after style changes; inspect visible app state when possible.

## Open questions
- None currently.
