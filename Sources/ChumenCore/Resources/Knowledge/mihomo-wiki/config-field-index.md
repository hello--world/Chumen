---
title: Mihomo Config Field Index
category: reference
tags: [config, yaml, rawconfig, fields, parse]
source_files: [config/config.go, hub/executor/executor.go, listener/listener.go, listener/parse.go, adapter/parser.go, adapter/outboundgroup/parser.go, rules/parser.go, hub/route/configs.go]
status: current
---

# Mihomo Config Field Index

Use this page when an AI agent needs to locate a YAML field, explain which subsystem owns it, or decide where to add a new field.

This is not a full user manual for every option. It is a source navigation index.

## Main Rule

Most top-level YAML fields enter through:

```text
config.RawConfig
  -> config.DefaultRawConfig
  -> config.UnmarshalRawConfig
  -> config.ParseRawConfig
  -> specific parseXxx function
  -> config.Config
  -> hub/executor.ApplyConfig
  -> runtime module
```

If a field appears in API patch logic, also inspect `hub/route/configs.go`.

## Top-Level Field Groups

| YAML fields | Raw owner | Parse owner | Runtime owner |
| --- | --- | --- | --- |
| `port`, `socks-port`, `redir-port`, `tproxy-port`, `mixed-port` | `RawConfig` | `parseGeneral` | `executor.updateListeners`, `listener.ReCreateXxx` |
| `allow-lan`, `bind-address`, `authentication`, LAN allow/deny lists | `RawConfig` | `parseGeneral` | `listener.SetAllowLan`, listener auth stores |
| `mode`, `tcp-concurrent`, `unified-delay`, `find-process-mode` | `RawConfig` | `parseGeneral` | `executor.updateGeneral`, `tunnel` |
| `log-level` | `RawConfig` | `parseGeneral` | `log.SetLevel`, `executor.updateGeneral` |
| `ipv6` | `RawConfig`, `RawDNS` | `parseIPV6`, `parseDNS` | resolver, DNS service, tunnel metadata resolution |
| `external-controller*`, `external-ui*`, `secret`, `external-doh-server` | `RawConfig` | `parseController` | `hub.applyRoute`, `route.ReCreateServer` |
| `proxies` | `RawConfig.Proxy` | `parseProxies`, `adapter.ParseProxy` | `tunnel.UpdateProxies` |
| `proxy-groups` | `RawConfig.ProxyGroup` | `parseProxies`, `outboundgroup.ParseProxyGroup` | groups are stored as proxies |
| `proxy-providers` | `RawConfig.ProxyProvider` | `parseProxies`, `adapter/provider.ParseProxyProvider` | `tunnel.UpdateProxies`, provider updates |
| `rules` | `RawConfig.Rule` | `parseRules`, `rules.ParseRule` | `tunnel.UpdateRules` |
| `sub-rules` | `RawConfig.SubRules` | `parseSubRules` | referenced by parsed rule objects |
| `rule-providers` | `RawConfig.RuleProvider` | `parseRuleProviders`, `rules/provider.ParseRuleProvider` | `tunnel.UpdateRules` |
| `listeners` | `RawConfig.Listeners` | `parseListeners`, `listener.ParseListener` | `listener.PatchInboundListeners` |
| `hosts` | `RawConfig.Hosts` | `parseHosts` | `resolver.DefaultHosts` |
| `dns` | `RawConfig.DNS` | `parseDNS` | `executor.updateDNS`, `dns.NewService`, `dns.ReCreateServer` |
| `tun` | `RawConfig.Tun` | `parseTun` | `executor.updateTun`, `listener.ReCreateTun` |
| `tuic-server` | `RawConfig.TuicServer` | `parseTuicServer` | `listener.ReCreateTuic` |
| `tunnels` | `RawConfig.Tunnels` | validation in `ParseRawConfig` | `executor.updateTunnels`, `listener.PatchTunnel` |
| `iptables` | `RawConfig.IPTables` | `parseIPTables` | `executor.updateIPTables` |
| `ntp` | `RawConfig.NTP` | `parseNTP` | `executor.updateNTP` |
| `profile` | `RawConfig.Profile` | `parseProfile` | `executor.updateProfile`, cachefile |
| `experimental` | `RawConfig.Experimental` | `parseExperimental` | `executor.updateExperimental` |
| `sniffer` | `RawConfig.Sniffer` | `parseSniffer` | `executor.updateSniffer`, `tunnel.preHandleMetadata` |
| `tls` | `RawConfig.TLS` | `parseTLS` | controller TLS, custom trust certs |
| `geox-url`, `geo-auto-update`, `geo-update-interval`, geodata fields | `RawConfig` | `parseGeneral` | updater and geodata components |
| `interface-name`, `routing-mark`, keepalive fields | `RawConfig` | `parseGeneral` | dialer and general runtime options |

## Config Field To Runtime Examples

### `mixed-port`

```text
RawConfig.MixedPort
  -> parseGeneral
  -> General.Inbound.MixedPort
  -> executor.updateListeners
  -> listener.ReCreateMixed
```

### `external-controller`

```text
RawConfig.ExternalController
  -> parseController
  -> Config.Controller.ExternalController
  -> hub.applyRoute
  -> route.ReCreateServer
  -> route.router
```

### `listeners`

```text
RawConfig.Listeners
  -> parseListeners
  -> listener.ParseListener
  -> listener/inbound.NewXxx
  -> Config.Listeners
  -> executor.updateListeners
  -> listener.PatchInboundListeners
```

### `proxy-providers`

```text
RawConfig.ProxyProvider
  -> parseProxies
  -> adapter/provider.ParseProxyProvider
  -> component/resource.Vehicle
  -> component/resource.Fetcher
  -> Config.Providers
  -> tunnel.UpdateProxies
```

### `rule-providers`

```text
RawConfig.RuleProvider
  -> parseRuleProviders
  -> rules/provider.ParseRuleProvider
  -> component/resource.Vehicle
  -> Config.RuleProviders
  -> tunnel.UpdateRules
```

### `sniffer`

```text
RawConfig.Sniffer
  -> parseSniffer
  -> Config.Sniffer
  -> executor.updateSniffer
  -> tunnel.preHandleMetadata
```

### `tun`

```text
RawConfig.Tun
  -> parseTun
  -> General.Tun
  -> executor.updateTun
  -> listener.ReCreateTun
  -> listener/sing_tun.New
  -> sing-tun tun.New / tun.NewStack
```

For macOS-specific TUN behavior, external fd handling, and NetworkExtension comparison, read [[tun-macos-native]].

## Supported Type Index

### Outbound proxy `type`

Defined in `adapter/parser.go`:

```text
ss, ssr, socks5, http, vmess, vless, snell, trojan, hysteria,
hysteria2, wireguard, tuic, gost-relay, direct, dns, reject, ssh,
mieru, anytls, sudoku, masque, trusttunnel, openvpn, tailscale
```

### Proxy group `type`

Defined in `adapter/outboundgroup/parser.go`:

```text
url-test, select, fallback, load-balance
```

`relay` is explicitly rejected and tells users to use `dialer-proxy` instead.

### Inbound listener `type`

Defined in `listener/parse.go`:

```text
socks, http, tproxy, redir, mixed, tunnel, tun, shadowsocks, snell,
vmess, vless, trojan, hysteria2, hysteria2-realm, tuic, anytls,
mieru, sudoku, trusttunnel
```

## Adding A New YAML Field

Use this checklist:

1. Add the field to `RawConfig` or a nested raw struct.
2. Add a default in `DefaultRawConfig` only if the zero value is not correct.
3. Parse it in the closest `parseXxx` function.
4. Add a runtime field to `Config` or the nested runtime struct if needed.
5. Apply it in `executor.ApplyConfig` at the right point.
6. If it is patchable via API, update `hub/route/configs.go`.
7. Add validation and tests.

Cross-reference: [[config-reference]], [[development-recipes]], [[api-route-map]].
