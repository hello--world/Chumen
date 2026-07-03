# Design

## Source of truth
- Status: Active
- Last refreshed: 2026-07-03
- Primary product surfaces: Native macOS Chumen app and its menu bar controller.
- Evidence reviewed: `Sources/ChumenMacApp/ContentView.swift`, `Sources/ChumenMacApp/AppModel.swift`, `Sources/ChumenMacApp/L10n.swift`, `README.md`, user screenshots of Chumen and macOS Settings.

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
- Core routes/screens: dashboard, profiles, proxies, providers, connections, rules, logs, core tools, settings.
- Content hierarchy: current runtime state first, then a compact global search launcher, then actions, metrics, and lists. Activating search opens a Spotlight-style top overlay that fully covers the header/search launcher, supports category scopes, and prioritizes settings results before runtime data.

## Design principles
- Principle 1: use low-contrast grouped surfaces with hairline borders instead of prominent floating cards.
- Principle 2: make state readable without oversized blocks or loud color.
- Tradeoffs: functional density is more important than decorative whitespace.

## Visual language
- Color: system adaptive backgrounds, subtle separators, green only for active/running, blue only for primary action.
- Typography: native system type, semibold for state values, captions for labels.
- Spacing/layout rhythm: compact utility spacing with grouped rows and consistent 8 px radius.
- Shape/radius/elevation: max 8 px radius for cards/panels; no heavy shadows on routine dashboard surfaces.
- Motion: system-default only.
- Imagery/iconography: SF Symbols and the app icon; no copied system app iconography beyond platform conventions.

## Components
- Existing components to reuse: header, command panel, metric tile, settings form, tab navigation.
- New/changed components: native grouped dashboard surfaces and localized status error copy.
- Variants and states: running/stopped, API reachable/unreachable, proxy on/off, TUN on/off, empty metrics.
- Token/component ownership: `ChumenStyle` in `ContentView.swift`.

## Accessibility
- Target standard: clear contrast and readable text at default macOS sizes.
- Keyboard/focus behavior: use system controls so focus rings and shortcuts remain native; global search accepts Return to open the first result, closes on outside click or Esc, debounces result generation, and avoids full search during single-letter IME composition.
- Contrast/readability: avoid low-contrast text over material blur.
- Screen-reader semantics: keep labels on buttons and status values.
- Reduced motion and sensory considerations: avoid nonessential animation.

## Responsive behavior
- Supported breakpoints/devices: resizable macOS app window.
- Layout adaptations: dashboard metrics wrap via adaptive grid.
- Touch/hover differences: pointer-first macOS interactions.

## Interaction states
- Loading: show existing status text and last refresh values.
- Empty: use dash placeholders.
- Error: localize common connectivity failures and keep technical details in logs/tools when needed.
- Success: concise status text.
- Disabled: use native disabled controls.
- Offline/slow network, if applicable: API status should indicate unreachable controller without visually dominating the dashboard.

## Content voice
- Tone: concise utility language.
- Terminology: use "core", "API", "TUN", "DNS", "Provider" consistently with the product.
- Microcopy rules: Chinese UI should not leak common Foundation networking errors in English.

## Implementation constraints
- Framework/styling system: SwiftUI/AppKit native controls.
- Design-token constraints: keep style tokens in `ChumenStyle`; no new theming layer.
- Performance constraints: dashboard updates must remain cheap during traffic/connection streams.
- Compatibility constraints: macOS native Swift Package app.
- Test/screenshot expectations: run Swift build/tests after style changes; inspect visible app state when possible.

## Open questions
- [ ] Final icon direction is still subject to user preference after the UI shell stabilizes.
