# Chumen UI Design System

中文版本: [ui-design-system.zh.md](ui-design-system.zh.md)

This document is the implementation-level design contract for Chumen UI work.
[DESIGN.en.md](../DESIGN.en.md) defines product direction; this file defines concrete visual rules
that future SwiftUI changes must follow. For PIN, config encryption, app lock, Keychain, runtime
plaintext, logging, and AI review boundaries, [security-model.en.md](security-model.en.md) is
authoritative.

## Design Goal

Chumen is a native macOS utility for operating mihomo. It should feel closer to System Settings,
Shortcuts, and a focused developer tool than to a web dashboard.

The default look is calm and system-native. Color is allowed, but only where it improves recognition
or action priority. Layout must stay compact enough for repeated use.

## Required Rules

- Use SwiftUI/AppKit system controls before custom controls.
- Use semantic macOS colors for surfaces and text.
- Keep rounded rectangles at `8` pt radius unless a system control supplies its own shape.
- Do not put cards inside cards. Use grouped rows, sections, dividers, or hint strips instead.
- Do not use large decorative gradients as page backgrounds.
- Do not rely on tiny gray text for important decisions.
- Do not hide important actions below a required scroll in the default app window.
- Validate visible UI with a screenshot after changing layout, color, or first-run flows.

## Color System

### Neutral Surfaces

Use these layers in order:

- Page: `Color(nsColor: .windowBackgroundColor)`
- Main surface: `Color(nsColor: .textBackgroundColor)`
- Grouped section: `Color(nsColor: .controlBackgroundColor)` with low opacity when needed
- Border: `Color(nsColor: .separatorColor)` at low opacity
- Primary text: `.primary`
- Secondary text: `ChumenStyle.mutedText` or `Color(nsColor: .secondaryLabelColor)`

Large panes, forms, lists, and setting groups should be neutral. A screen should not read as mostly
blue, purple, beige, orange, brown, or dark slate.

### Accent Usage

Use accent colors deliberately:

- Blue: primary command, focused search, selected segmented control.
- Green: running/healthy/active state only.
- Red/orange: destructive, warning, or risk tradeoff only.
- Teal, violet, orange: small icon tiles, category hints, or local visual anchors.

Shortcuts-style color is allowed for small identity blocks: icons, badges, and compact hint accents.
It is not allowed for large background bands, page backgrounds, or full-width cards that are only
informational.

### Gradients

Gradients are allowed only for:

- app/security icon blocks,
- very small category badges,
- empty-state illustrations if they are not competing with controls.

Do not use gradients behind forms, tables, settings groups, or routine dashboard metrics.

## Typography

Use system text styles, not hardcoded font sizes, unless the UI is a fixed-format status value.

- Page/sheet title: `.title3.weight(.semibold)` or `.title2.weight(.semibold)`
- Section title: `.headline` or `.subheadline.weight(.semibold)`
- Main form/control text: `.body` or `.callout`
- Secondary explanation: `.callout` when important, `.caption` only for low-priority hints
- Metric values: `.title2.weight(.semibold)` or `.title3.weight(.semibold)`

Important setup decisions must not be caption-sized. If the user must understand a security or
configuration consequence, use at least `.callout`.

## Layout Rhythm

- Outer screen padding: `20` to `28` pt.
- Group padding: `12` to `16` pt.
- Form row spacing: `8` to `12` pt.
- Section spacing: `12` to `18` pt.
- Default max sheet width: `680` to `840` pt depending on content.
- Default radius: `ChumenStyle.radius` (`8` pt).
- Routine shadows should be absent or extremely subtle.

Use dividers for separation inside grouped sections. Avoid multiple bordered boxes stacked inside
another bordered box.

## Component Rules

### Settings Forms

Settings screens should look like native grouped forms:

- left label, right control for simple settings;
- one grouped section per concept;
- explanatory text below the control only when needed;
- edits persist automatically unless applying to a running core is inherently a separate action.

Avoid isolated floating buttons in a large blank area. Put actions near the setting or in a clear
footer row.

### First-Run Security Setup

This flow protects the age private key and runs before profile import on first launch. Its product
semantics must follow [security-model.en.md](security-model.en.md); UI changes here must not
reinterpret PIN protection as app lock.

Default behavior:

- configuration files are encrypted by default;
- PIN protection for the age private key is enabled by default;
- app lock is a separate option and defaults off;
- users can continue without PIN, but the copy must say the config still stays encrypted.

Layout rules:

- must fit in the default window without required scrolling;
- left side explains the purpose with one icon and short copy;
- right side contains the actual controls;
- storage location is a compact row with a segmented picker;
- show only one generated PIN field by default;
- the generated PIN is visible by default because the app created it for the user;
- provide an eye toggle and a regenerate icon button;
- do not show a second identical confirmation field unless the user explicitly chooses a custom
  password flow;
- app lock is a separate toggle below the PIN field;
- primary action is `启用 PIN 加密`;
- secondary action is `不用 PIN，继续`;
- explanations are hints, not actions: put them in the left summary panel or a light hint strip
  with small colored icons; do not make them look like selectable cards.

The user should be able to answer these questions immediately:

- What is being protected?
- Where is the age private key saved?
- What is my generated PIN?
- Is app lock enabled?
- What happens if I continue without PIN?

### Startup Import

The import prompt appears after security setup when no profile exists.

- Keep the title direct: no proxy config exists.
- Primary action: scan/import existing configs.
- Secondary action: import local YAML or continue later.
- The scanned candidate list must provide search by profile name, source client, and path.
- During search, "Import All" applies only to currently filtered results so hidden items are not
  imported by surprise.
- Imported profiles must not keep the original app name in the display title; source app belongs in
  metadata or notes.

### Profile Library

The Profiles page is a profile-library management surface, not a page where every import form and
every profile action is flattened into one visual layer.

- The left rail contains entry points: new profile, import local YAML, import subscription, scan
  other clients, and global override config.
- New profile is the highest-priority entry. Clicking it creates a minimal runnable YAML profile and
  opens the editor immediately.
- The right side is a profile list; each profile is a scannable row, not a large card.
- Inline row actions are limited to common tasks: edit, edit rules, edit nodes, update, and more.
- Low-frequency or risky actions belong under "More": edit proxy groups, override config, script,
  open file, update via proxy, and delete.
- The active profile shows a single "current" status. Do not show both active and current at once.
- Source client, subscription URL, and file path are metadata, not part of the primary title.
- The profile list needs local search by name, path, source client, and subscription URL.

### Search

The header search is a launcher. Activating it opens a larger Spotlight-style overlay.

- Active overlay must cover the launcher so two search fields are not visible.
- Results should prioritize settings/core matches, then profiles/proxies/providers/rules/connections/logs.
- Searching must be debounced and must not block typing or Chinese IME composition.
- Empty result count must reflect displayed results, not a hidden total.

### Header Status Bar

The header is a single utility shell, not a long horizontal status waterfall.

- Keep app identity and the running profile fixed on the left.
- Keep the search launcher at a moderate width; do not stretch it indefinitely on wide windows.
- Stack `API` above config update as one group.
- Put system proxy on the upper row, with `mode` and `TUN` side by side below it.
- Tighten group widths before hiding these key states.
- Keep the header's original horizontal layout. Header width must not be changed as a side effect of
  making dashboard cards taller.

### Dashboard And Metrics

Dashboard surfaces should be dense and calm:

- metrics are scan tiles, not marketing cards;
- dashboard main content keeps its existing horizontal width; command panels and metric sections use
  roughly 20% more vertical rhythm through `ChumenStyle.dashboardVerticalScale`;
- traffic and speed values need stable dimensions;
- no large single-color sections;
- status color follows state: green for active/healthy, gray for inactive, orange/red for failure.

### Provider And Proxy Lists

List columns should align consistently.

- Policy selectors in a column should have consistent width.
- Action buttons keep text labels unless the function is obvious from a familiar symbol.
- Long lists should use subtle row backgrounds and separators, not floating cards per row.
- Dropdown menus must not blur, crop, or visually leak content behind them.

### AI Assistant

The AI assistant is a review-first tool.

- It may search locally when no model endpoint/key is configured.
- It is fixed as a right-side rail on the overview page, not a bottom-right floating button. Users
  can collapse it into a narrow right rail. Profiles, proxies, providers, connections, rules, logs,
  and settings must not lose width to the AI rail.
- Model settings must use a stateful segmented control to distinguish Local Ollama from custom
  endpoints. Local Ollama model selection must call `/api/tags`; selecting a model or typing another
  model name writes it immediately. Do not hardcode a local model name in UI defaults.
- Model-generated operations produce pending diffs.
- The user must review and apply changes manually.
- No AI response may directly mutate profiles, rules, settings, proxy/TUN state, or runtime config.

## Accessibility And Verification

Every UI change must pass these checks before completion:

- text fits at the default window size;
- no required action is hidden below a scroll in first-run flows;
- focus rings do not appear behind overlays;
- buttons have labels or tooltips;
- important explanatory copy is readable at normal screenshot scale;
- color is not the only state signal;
- `swift test` passes for logic changes;
- app screenshot is inspected for visual changes.

## Maintenance

When a UI decision conflicts with this file, update this file first or document the exception in the
code near the component. Future agents should treat this file as the design source for detailed UI
implementation.
