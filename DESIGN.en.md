# Chumen Design

中文版本: [DESIGN.zh.md](DESIGN.zh.md)

## Source Of Truth

- Status: Active.
- Last refreshed: 2026-07-05.
- Primary product surfaces: native macOS Chumen app and menu bar controller.
- Evidence reviewed: `Sources/ChumenMacApp/ContentView.swift`, `Sources/ChumenMacApp/AppModel.swift`, `Sources/ChumenMacApp/L10n.swift`, `README.en.md`, `docs/security-model.en.md`, user screenshots, macOS Settings, and Shortcuts references.
- Detailed UI contract: `docs/ui-design-system.en.md`.
- Security, PIN, app lock, Keychain, runtime plaintext, logging, and AI review boundaries:
  `docs/security-model.en.md`.
- Documentation language: project documentation must include Chinese and English. Chinese should
  make user-facing consequences clear; English should preserve the same engineering constraints.

## Brand

- Personality: quiet, native, technical, reliable.
- Trust signals: clear state, reversible controls, direct core/API feedback, readable Chinese copy.
- Avoid: web-dashboard card stacks, heavy gray banners, strong shadows, decorative gradients, and
  copied macOS Settings layouts.

## Product Goals

- Goals: make core status, proxy state, TUN, traffic, and operations easy to scan and control.
- Non-goals: theme customization and decorative marketing UI.
- Success signal: the app feels like a small macOS utility, not a web page embedded in a window.

## Personas And Jobs

- Primary personas: macOS users running mihomo locally.
- User jobs: start/stop the core, inspect status, switch policies, manage providers, diagnose
  connections, and tune runtime settings.
- Key contexts: menu bar quick checks, repeated dashboard scanning, and occasional advanced
  configuration.

## Information Architecture

- Primary navigation: top tab bar.
- Core screens: dashboard, profiles, proxies, providers, connections, rules, core, core tools, logs,
  and settings.
- Content hierarchy: current runtime state first, then global search, then actions, key metrics,
  diagnostic summaries, and linked related information.
- Header: keep one outer row with app/running state on the left and a modest-width search launcher
  in the middle. Status facts are grouped vertically by meaning: `API` above config update, and
  system proxy above `mode + TUN`, so the header does not become an overlong horizontal ribbon.
- Dashboard rhythm: keep the existing horizontal measure and increase only the command/metric
  vertical rhythm by roughly 20%. Do not narrow the main content as a side effect of making it taller.
- Search: the header search is only a launcher. Activating it opens a Spotlight-style overlay that
  covers the header/search launcher so no duplicate search field or status leaks through. Results
  prioritize settings and core, then profiles, proxies, providers, rules, connections, and logs.
- AI: a fixed right-side chat rail is visible by default and can collapse into a narrow right rail.
  Local Ollama is the preferred path at
  `http://127.0.0.1:11434/v1` and does not need a key. Remote OpenAI-compatible endpoints require a
  saved key. Without a usable model, the panel behaves as local search.
- Settings boundary: `内核` owns mihomo/runtime config; `设置` owns Chumen preferences. Ordinary
  settings persist automatically; saved core changes that affect a running core need an explicit
  apply action.

## Design Principles

- Use low-contrast grouped surfaces with hairline borders instead of prominent floating cards.
- Make state readable without oversized blocks or loud color.
- Use native SwiftUI/AppKit controls and semantic colors first; custom color should be a small
  identity or action accent.
- Functional density matters more than decorative whitespace.
- The dashboard must be a modular command surface: feature modules expose key state, diagnostics,
  and links through Dashboard providers; the page owns sorting and rendering, not business-specific
  card stacking.

## Visual Language

- Color: system adaptive backgrounds; green only for running/healthy/active state; blue only for
  primary action or focus.
- Typography: native system type; semibold for state values; captions/callouts for labels.
- Spacing: compact utility rhythm with consistent grouped rows and lists.
- Shape/elevation: routine radius is at most 8 pt; no heavy shadows on routine dashboard surfaces.
- Motion: system-default only.
- Iconography: SF Symbols and the app icon. Menu bar status uses door variants: closed means traffic
  is not captured, half-open means system proxy is active, open means effective TUN routing.

## Components

- Reuse: header, command panel, Dashboard item/section, settings form, top tab navigation.
- Key components: global search overlay, compact header status strip, modular dashboard providers,
  core quick navigation, separate settings form, first-run security setup, AI review panel, and menu
  bar status icon variants.
- States: running/stopped, API reachable/unreachable, proxy on/off, TUN on/off, empty metrics, local
  Ollama ready, remote AI key missing, AI pending diff.
- Style token owner: `ChumenStyle` in `ContentView.swift`.

## Accessibility

- Target: readable at default macOS sizes.
- Keyboard/focus: use system controls; search supports Return for the first result, Esc/outside click
  to close, debounced result generation, no blocking Chinese IME composition, and off-main-thread
  list scanning.
- Contrast: avoid low-contrast text over material blur.
- Screen reader: keep labels on buttons and status values.
- Motion: avoid nonessential animation.

## Responsive Behavior

- Supported surface: resizable macOS app window.
- Dashboard sections and items wrap through an adaptive grid. A module may provide state, metrics,
  diagnostics, or links, but each item needs a stable title, value, priority, and action semantics.
- The header shell stays in one row while status pills may stack inside their groups. In narrow
  windows, tighten search/status group widths before hiding `API`, config update, system proxy,
  mode, or TUN.
- Dashboard pages keep their existing horizontal width. Use `ChumenStyle.dashboardVerticalScale` only
  to increase command and metric height.

## Interaction States

- Loading: keep existing status text and last refresh values.
- Empty: use dash placeholders.
- Error: localize common connectivity failures and put technical details in logs/tools.
- Success: concise status text.
- Disabled: native disabled controls.
- AI draft review: every AI-suggested operation is a temporary proposal with a git-like diff. The
  user must explicitly apply it before config, rules, proxy/TUN, system proxy, or runtime config can
  change.

## Security And Privacy Model

- Source of truth: `docs/security-model.en.md`.
- Configuration is encrypted by default with the mihomo age path; do not add another long-term config
  encryption format.
- PIN has two independent meanings: age private-key protection and optional application lock. PIN
  protection is on by default; application lock is off by default.
- Default startup should auto-unlock the PIN-protected age key using Chumen's local wrapping key, so
  the app behaves normally unless app lock is enabled.
- Enabling app lock must remove the auto-unlock path and require PIN on launch. Disabling app lock
  may recreate auto-unlock only from an already unlocked age key.
- Do not explain or implement app lock as a side effect of enabling PIN.
- Default age private-key storage is local file; Keychain is optional.
- Do not use a fixed salt as the default decrypt mechanism. PIN derivation uses a random per-vault
  salt; default auto-unlock uses a random local wrapping key.
- Fixed Application Support runtime config may contain only protected data when config protection is
  enabled. Unavoidable plaintext runtime material must use a random temporary session directory and
  an explicit cleanup owner.
- Every user-visible security/runtime notification must also be logged with sanitized context. Never
  log PINs, API keys, controller secrets, age private keys, decrypted profiles, or credential-bearing
  subscription URLs.

## Content Voice

- Tone: concise utility language.
- Terminology: use "core", "API", "TUN", "DNS", and "Provider" consistently.
- Chinese UI should not leak common Foundation networking errors in English.

## Implementation Constraints

- Framework: native SwiftUI/AppKit controls.
- Tokens: keep style tokens in `ChumenStyle`; do not add a new theming layer.
- UI contract: check `docs/ui-design-system.en.md` before UI changes. If implementation needs an
  exception, update the document first or add a local code intent note near the component.
- Dashboard additions should be implemented as provider/item data first, not as module-specific
  views hardcoded in `DashboardView`; logs, connections, rules, providers, and similar modules can
  register important summaries and navigation links.
- Dashboard quick-action buttons must also be published through provider/item data. Start, stop,
  refresh, system proxy, TUN, settings entries, and module jumps all use the same quick-entry
  contract.
- Dashboard quick controls must be layered by priority: start, stop, restart, refresh, system proxy,
  TUN, and edit quick controls stay in the first pinned row; user-added startup/quit preferences,
  network options, and module jumps may only appear in lower extension rows so they cannot disrupt
  the core controls.
- Performance: dashboard updates must remain cheap during traffic/connection streams.
- Security: AI API keys are stored in Keychain; local Ollama does not require a key; model calls use
  user-configured OpenAI-compatible endpoints.
- Verification: run Swift build/tests after style changes; inspect visible UI state when possible.

## Open Questions

- None currently.
