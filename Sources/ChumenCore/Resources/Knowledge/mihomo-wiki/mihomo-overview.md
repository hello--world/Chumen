---
title: Mihomo Overview
category: architecture
tags: [architecture, overview, mihomo, proxy-core]
source_files: [main.go, config/config.go, hub/hub.go, hub/executor/executor.go, tunnel/tunnel.go]
status: current
---

# Mihomo Overview

## Canonical Facts

- Mihomo is a Go proxy core.
- The module path is `github.com/metacubex/mihomo`.
- The main executable entrypoint is `main.go`.
- The minimum Go version in `go.mod` is Go 1.20.
- The core runtime path is:

```text
main.go
  -> hub.Parse
  -> config.Parse
  -> hub.ApplyConfig
  -> executor.ApplyConfig
  -> listener / tunnel / adapter / rules / dns / route
```

## Architecture Layers

```text
Application traffic
  -> listener
  -> Metadata
  -> tunnel
  -> rules
  -> adapter
  -> transport/protocol
  -> remote destination
```

## Major Modules

| Module | Responsibility |
| --- | --- |
| `main.go` | CLI flags, config source selection, lifecycle, signal handling |
| `config/` | YAML to RawConfig to Config |
| `hub/` | Config application and REST API coordination |
| `hub/executor/` | Runtime module update orchestration |
| `listener/` | Inbound listeners |
| `tunnel/` | Core TCP/UDP dispatch and rule matching |
| `rules/` | Rule parsing and rule implementations |
| `adapter/` | Outbound proxy abstraction and wrapping |
| `adapter/outbound/` | Concrete outbound proxy implementations |
| `adapter/outboundgroup/` | select, url-test, fallback, load-balance groups |
| `adapter/provider/` | Proxy providers |
| `rules/provider/` | Rule providers |
| `dns/` | DNS resolver service and server |
| `component/` | Reusable feature components |
| `transport/` | Protocol-level transport implementations |

## Mental Model

For beginner answers, use this explanation:

```text
listener decides where traffic enters.
Metadata describes the traffic.
tunnel decides how to handle it.
rules decide which outbound name to use.
adapter performs the outbound connection.
transport implements protocol details.
```

## Important Boundaries

- Config parsing must not be confused with runtime application.
- listener receives traffic but does not decide final routing.
- tunnel owns routing decisions.
- adapter owns outbound behavior.
- transport owns protocol details.
- provider owns remote or local list loading.

## Evidence Anchors

- `main.go` contains CLI flag registration, special subcommands, config loading, signal handling.
- `config/config.go` contains `RawConfig`, `Config`, `Parse`, `DefaultRawConfig`, `ParseRawConfig`.
- `hub/hub.go` contains `Parse`, `ApplyConfig`, `applyRoute`.
- `hub/executor/executor.go` contains `ApplyConfig` and update functions.
- `tunnel/tunnel.go` contains `HandleTCPConn`, `HandleUDPPacket`, `resolveMetadata`, `match`.

## Common Answer Template

If asked "what is Mihomo?":

> Mihomo is a Go proxy core. It listens for local HTTP/SOCKS/TUN/transparent traffic, converts each request into Metadata, uses tunnel and rules to choose an outbound proxy, then forwards TCP or UDP traffic through adapter implementations such as direct, Shadowsocks, VLESS, Trojan, Hysteria and others.
