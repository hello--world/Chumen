---
title: "Chumen Runtime, System Proxy, And TUN Knowledge"
tags: ["chumen", "runtime", "core", "system-proxy", "tun", "ports", "status"]
created: 2026-07-05T14:30:00Z
updated: 2026-07-05T14:30:00Z
sources:
  - README.en.md
  - DESIGN.en.md
  - Sources/ChumenMacApp/AppModel.swift
  - Sources/ChumenMacApp/CoreViews.swift
  - Sources/ChumenMacApp/AppUpdateCoordinator.swift
links:
  - chumen-runtime-and-system.zh.md
  - chumen-troubleshooting.en.md
category: reference
confidence: high
schemaVersion: 1
---

# Chumen Runtime, System Proxy, And TUN Knowledge

中文版本: [chumen-runtime-and-system.zh.md](chumen-runtime-and-system.zh.md)

## State Sources

Chumen has three kinds of state:

- App state: profile library, settings, language, AI provider, PIN, sync, and menu bar preferences. Usually independent of the core API.
- External system state: macOS system proxy. It is read and written through `networksetup` and should be refreshed by the shared update coordinator.
- Runtime core state: version, proxy groups, providers, rules, connections, traffic, memory, logs, DNS/storage/raw API. Requires the mihomo controller.

"Could not connect to core API" only means the third category is unavailable. It does not invalidate app knowledge, profile editing, or offline drafts.

## Core Lifecycle

Common operations:

- Start: generate runtime YAML and start mihomo.
- Stop: stop the core started by Chumen.
- Restart: stop and start, or use controller kernel restart.
- Refresh: reread runtime snapshots.
- Reload runtime config: regenerate runtime YAML and ask the controller to reload.

Before starting the core, Chumen creates a managed launch path. The default process-name suffix is `door`, so the process name is `chumen-door`. Custom process names must use a Chumen-controlled `chumen-` prefixed path, preferably a symlink to the real core.

## Default Ports

Chumen defaults intentionally avoid common proxy clients:

- mixed: `19881`
- SOCKS: `19882`
- HTTP: `19883`
- controller: `19897`

Ports are Chumen-owned settings and override the original profile during runtime YAML generation. Port changes need apply/reload before affecting a running core.

## System Proxy

System proxy is the HTTP/SOCKS proxy setting on macOS network services.

- Enabling system proxy points network services at Chumen's local proxy address.
- Disabling system proxy clears Chumen-written proxy settings.
- If another proxy owns the system setting, Chumen should show "other proxy" rather than claiming it is enabled by Chumen.
- Set system proxy after start and clear system proxy on stop are Chumen preferences.

System proxy status can refresh while the core is stopped because it is external macOS state.

## TUN

TUN is startup-level network routing capability.

- Enabling TUN affects core startup config; changing it while running usually requires a core restart.
- On macOS, TUN may require the privileged helper.
- `enableTunOnStart` controls whether TUN is enabled at startup.
- `disableTunOnQuit` controls whether Chumen disables TUN config on quit to avoid capturing traffic on the next automatic start.
- On quit, Chumen must stop the core it started to avoid leftover TUN or proxy processes.

## Core Settings Page

The Core page owns mihomo/runtime settings:

- Executable path.
- Managed process name.
- Controller secret.
- Auto-start core on app launch.
- mixed/SOCKS/HTTP/redir/tproxy ports.
- allow-lan, IPv6, unified-delay, TCP concurrent, find process.
- Basic and advanced TUN settings.
- Basic and advanced DNS settings.
- External UI.
- Global YAML appendix.

Ordinary settings may autosave; settings that affect a running core require explicit apply/reload.

## Core Tools Page

Core tools depend on the core API:

- reload runtime config.
- restart kernel API.
- open external dashboard.
- flush fake-IP, flush DNS, debug GC.
- update/upgrade Geo.
- DNS query.
- storage get/put/delete.
- raw API requests.

If the core API is unreachable, these tools fail, but profile editing remains available.
