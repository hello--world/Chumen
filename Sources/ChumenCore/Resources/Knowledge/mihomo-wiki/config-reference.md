---
title: Mihomo Config Reference For Agents
category: reference
tags: [config, yaml, parse, runtime, fields]
source_files: [config/config.go, config/initial.go, hub/executor/executor.go, listener/listener.go, adapter/parser.go, rules/parser.go]
status: current
---

# Mihomo Config Reference For Agents

## Core Types

| Type | Meaning |
| --- | --- |
| `RawConfig` | YAML-facing structure |
| `Config` | Runtime-facing parsed structure |
| `General` | Ports, mode, IPv6, interface, geodata, keepalive |
| `Controller` | RESTful API and UI settings |
| `DNS` | DNS resolver and server settings |
| `Inbound` | Top-level inbound ports and settings |

## Parse Chain

```text
config.Parse
  -> UnmarshalRawConfig
    -> DefaultRawConfig
    -> age.DecryptBytes
    -> yaml.Unmarshal
  -> ParseRawConfig
```

## ParseRawConfig Order

```text
parseGeneral
temporaryUpdateGeneral
parseController
parseExperimental
parseIPTables
parseNTP
parseProfile
parseTLS
parseProxies
parseListeners
parseRuleProviders
parseSubRules
parseRules
parseHosts
parseIPV6
parseDNS
parseTun
parseTuicServer
parseAuthentication
verify tunnels
parseSniffer
```

## Important Defaults

| Field | Default |
| --- | --- |
| `allow-lan` | false |
| `bind-address` | `*` |
| `mode` | rule |
| `ipv6` | true |
| `log-level` | info |
| `dns.enable` | false |
| `dns.enhanced-mode` | mapping |
| `dns.fake-ip-range` | `198.18.0.1/16` |
| `tun.enable` | false |
| `tun.stack` | gvisor |
| `geo-auto-update` | false |
| `geodata-loader` | memconservative |
| `profile.store-selected` | true |
| `etag-support` | true |

## Field Flow Map

### mixed-port

```text
RawConfig.MixedPort
  -> parseGeneral
  -> Config.General.Inbound.MixedPort
  -> executor.updateListeners
  -> listener.ReCreateMixed
```

### mode

```text
RawConfig.Mode
  -> parseGeneral
  -> Config.General.Mode
  -> executor.updateGeneral
  -> tunnel.SetMode
```

### proxies

```text
RawConfig.Proxy
  -> parseProxies
  -> adapter.ParseProxy
  -> outbound.NewXxx
  -> adapter.NewProxy
  -> Config.Proxies
  -> executor.updateProxies
  -> tunnel.UpdateProxies
```

### proxy-groups

```text
RawConfig.ProxyGroup
  -> parseProxies
  -> proxyGroupsDagSort
  -> outboundgroup.ParseProxyGroup
  -> Config.Proxies
```

### rules

```text
RawConfig.Rule
  -> parseRules
  -> rules/common.ParseRulePayload
  -> rules.ParseRule
  -> rules/wrapper.NewRuleWrapper
  -> Config.Rules
  -> executor.updateRules
  -> tunnel.UpdateRules
```

### listeners

```text
RawConfig.Listeners
  -> parseListeners
  -> listener.ParseListener
  -> Config.Listeners
  -> executor.updateListeners
  -> listener.PatchInboundListeners
```

### dns

```text
RawConfig.DNS
  -> parseDNS
  -> Config.DNS
  -> executor.updateDNS
  -> dns.NewResolver
  -> dns.NewService
  -> dns.ReCreateServer
```

## Safe Path Rules

Source: `constant/path.go`.

Paths must be under:

- home dir from `-d`
- or paths in `SAFE_PATHS`

Unless:

- `SKIP_SAFE_PATH_CHECK=true`
- or `features.CMFA`

Common affected settings:

- `external-ui`
- provider `path`
- TLS certificate/private key paths
- ECH key paths

## Config Validation Command

```sh
bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-learning -t -f docs/learning-minimal.yaml
```

## Common Errors

| Error | Likely Cause |
| --- | --- |
| `proxy ... not found` | Rule or group references missing proxy |
| `rule set ... not found` | RULE-SET references missing rule provider |
| `format invalid` | Bad rule format |
| `duplicate name` | Duplicate proxy/group/listener name |
| `path is not subpath` | Path outside home dir or SAFE_PATHS |
| `unsupported type` | Wrong proxy/listener/provider type |
