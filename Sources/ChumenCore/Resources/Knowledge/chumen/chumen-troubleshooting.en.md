---
title: "Chumen Troubleshooting Knowledge"
tags: ["chumen", "troubleshooting", "errors", "core-api", "tun", "proxy", "logs"]
created: 2026-07-05T14:30:00Z
updated: 2026-07-05T14:30:00Z
sources:
  - README.en.md
  - docs/security-model.en.md
  - Sources/ChumenMacApp/AppModel.swift
  - Sources/ChumenMacApp/RulesLogsViews.swift
  - Sources/ChumenCore/LogAnalysis.swift
links:
  - chumen-troubleshooting.zh.md
  - chumen-runtime-and-system.en.md
category: debugging
confidence: high
schemaVersion: 1
---

# Chumen Troubleshooting Knowledge

中文版本: [chumen-troubleshooting.zh.md](chumen-troubleshooting.zh.md)

## Could Not Connect To Core API

Meaning: Chumen cannot currently reach the mihomo controller.

Affected:

- Proxy groups, providers, rules, connections, traffic, memory, and core tools may be unavailable or stale.
- Profile library, profile editing, append overlays, tutorial answers, and offline AI drafts remain available.

Check:

1. Whether the core is started.
2. Whether controller host/port match settings.
3. Whether an external core owns the port.
4. Logs page and `logs/sidecar.log`.
5. If port or secret just changed, regenerate and reload/restart.

## Core Not Running

Meaning: Chumen has no active mihomo core.

Still available:

- Profile editing.
- Subscription import.
- Settings editing.
- AI draft preparation.

Requires core startup:

- Live proxy list.
- Runtime connections and rules.
- Traffic, memory, log streams.
- Core tool API calls.

## Config Change Does Not Take Effect

Common causes:

- Config was saved but not applied or reloaded.
- A node was added through an overlay but not added to any proxy group.
- New rules are shadowed by earlier rules and need `prepend`.
- Runtime API reload failed.
- The user is inspecting a different active profile.

Debug path:

1. Confirm the active profile.
2. Check the correct append overlay section.
3. Generate runtime YAML or use reload runtime config.
4. Inspect logs for config parse errors.
5. For field semantics, consult the mihomo knowledge base.

## System Proxy Issues

Symptoms:

- Header shows another proxy.
- System proxy is enabled but traffic does not go through Chumen.
- System proxy remains after stop.

Explanation:

- System proxy is external macOS state and may be changed by other apps.
- Chumen should clean up its own written state or the state configured for cleanup.
- Refreshing system proxy state does not require the core API.

## TUN Failure

Common causes:

- Helper is not installed or unavailable.
- Insufficient privilege.
- Invalid TUN config fields.
- TUN changed while running without restart.
- Quit cleanup did not match settings.

Check:

1. Logs and notifications.
2. Helper status.
3. Restart the core instead of only reload.
4. TUN/DNS config.
5. For macOS native networking behavior, consult mihomo `tun-macos-native`.

## Bad AI Answer

If AI answers a tutorial question with "could not connect to core API", routing is wrong.

Correct logic:

- "How do I add a proxy/rule/subscription" uses the Chumen app knowledge base.
- "What proxies/rules/connections are currently active" depends on the core API.
- Exact YAML fields use the mihomo knowledge base.

## Where To Look

- GUI Logs page: app logs, runtime logs, issue analysis.
- `logs/sidecar.log`: persistent events and core stdout/stderr.
- Core Tools page: DNS/storage/raw API checks when API is online.
- Config page: active profile and append overlays.
- Settings page: system proxy, TUN, auto cleanup, language, and AI settings.
