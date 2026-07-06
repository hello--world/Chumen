---
title: Mihomo TUN And macOS Native Networking
category: architecture
tags: [tun, macos, darwin, networkextension, packet-tunnel, utun, sing-tun]
source_files: [config/config.go, constant/tun.go, listener/listener.go, listener/sing_tun/server.go, listener/sing_tun/tun_name_darwin.go, listener/inbound/tun.go, listener/config/tun.go, docs/config.yaml, go.mod]
status: current
---

# Mihomo TUN And macOS Native Networking

Use this page when an AI agent needs to answer:

- how Mihomo TUN works on macOS
- whether it uses Apple NetworkExtension
- how it differs from `NEPacketTunnelProvider`
- whether Mihomo's implementation can be used as a reference for a macOS native app

## Short Answer

Mihomo's runtime implementation uses `listener/sing_tun` and `github.com/metacubex/sing-tun`. On macOS it uses `utunN` style interface naming and can optionally consume an externally supplied TUN file descriptor.

This repository does not implement an Apple `NEPacketTunnelProvider`. The production Go source does not define or call `NEPacketTunnelProvider`, `NETunnelProviderManager`, `NEPacketTunnelFlow`, or `packetFlow`.

Mihomo TUN can be referenced for proxy-core integration, routing option design, DNS hijack behavior, stack selection, reload lifecycle, and Darwin `utun` handling. A macOS native VPN app still needs a NetworkExtension wrapper and a packet-flow adapter.

## Repo Evidence

### Dependencies

`go.mod` includes:

```text
github.com/metacubex/sing-tun v0.4.20
```

Related networking dependencies include WireGuard and gVisor packages, but the TUN listener path is centered on `sing-tun`.

### TUN Stack Enum

`constant/tun.go` defines:

```text
TunGvisor -> "gVisor"
TunSystem -> "System"
TunMixed  -> "Mixed"
```

YAML parsing accepts lowercase stack names through `StackTypeMapping`.

### Config Owner

`config/config.go` defines `RawTun` with fields including:

```text
enable
device
stack
dns-hijack
auto-route
auto-detect-interface
mtu
gso
route-address
route-exclude-address
include-interface
exclude-interface
file-descriptor
recvmsgx
sendmsgx
```

Default values in `DefaultRawConfig`:

```text
Enable = false
Device = ""
Stack = C.TunGvisor
DNSHijack = ["0.0.0.0:53"]
AutoRoute = true
AutoDetectInterface = true
Inet6Address = fdfe:dcba:9876::1/126
RecvMsgX = true
SendMsgX = false
```

`parseTun` maps `RawTun` to `LC.Tun`. It derives the IPv4 TUN address from `dns.FakeIPRange`, falling back to `198.18.0.1/16`, then reducing it to a `/30` prefix.

### Runtime Creation Flow

```text
config.ParseRawConfig
  -> parseTun
  -> general.Tun
  -> hub/executor.updateTun
  -> listener.ReCreateTun
  -> sing_tun.New
  -> tun.New
  -> tun.NewStack
  -> tunStack.Start
```

`listener/listener.go` owns `ReCreateTun`. It sorts config, compares with `LastTunConf`, closes the old listener when changed, skips creation when disabled, and calls `sing_tun.New` when enabled.

### Darwin Interface Naming

`listener/sing_tun/server.go`:

- `CalculateInterfaceName` uses `utun` as the base name on Darwin.
- `checkTunName` requires Darwin names to start with `utun` and be followed by a number.
- Invalid Darwin names are rejected and regenerated.

`listener/sing_tun/tun_name_darwin.go` uses `unix.GetsockoptString` with `SYSPROTO_CONTROL` and `UTUN_OPT_IFNAME` to obtain the real interface name from a file descriptor.

### External TUN File Descriptor

`RawTun.FileDescriptor` is passed to `LC.Tun` and then into `tun.Options.FileDescriptor`.

In `sing_tun.New`, when `FileDescriptor > 0`:

```text
getTunnelName(fd)
use real tunnel name for sing-tun
pass FileDescriptor to tun.Options
```

Inference: the repository has a hook for consuming an externally created TUN fd. This is useful for native wrappers, but it is not itself a NetworkExtension implementation.

### Handler And Stack

`sing_tun.New` creates:

```text
sing.NewListenerHandler({
  Tunnel: tunnel,
  Type: C.TUN
})
```

Then it configures:

```text
tun.Options
tun.New(tunOptions)
tun.StackOptions
tun.NewStack(strings.ToLower(options.Stack.String()), stackOptions)
tunStack.Start()
```

This is the bridge from TUN IP packets into Mihomo's normal listener/tunnel/rules/outbound pipeline.

## Apple Native Model

Primary Apple concepts:

| Apple API | Role |
| --- | --- |
| `NEPacketTunnelProvider` | Packet tunnel app extension that gets access to virtual interface packets through `packetFlow` |
| `NEPacketTunnelNetworkSettings` | Virtual interface settings: addresses, DNS, routes, MTU and related flags |
| `NETunnelProviderManager` | Containing app object for creating, saving, and controlling VPN configurations |
| `NEAppProxyProvider` | Flow-level app proxy provider, not raw IP packet TUN |
| `NEFilterDataProvider` | Content filtering provider, not a proxy-core replacement |

Official references:

- <https://developer.apple.com/documentation/networkextension/nepackettunnelprovider>
- <https://developer.apple.com/documentation/networkextension/nepackettunnelnetworksettings>
- <https://developer.apple.com/documentation/networkextension/netunnelprovidermanager>
- <https://developer.apple.com/documentation/networkextension/routing-your-vpn-network-traffic>
- <https://github.com/ios-sample-code/SimpleTunnel>

Apple's model requires NetworkExtension entitlement and an App Extension target. The packet tunnel provider uses `setTunnelNetworkSettings` to configure the virtual interface and `packetFlow` to read and inject packets.

## Comparison Matrix

| Question | Mihomo TUN | Apple Packet Tunnel |
| --- | --- | --- |
| Is it in this repo? | Yes | No |
| Main implementation | `listener/sing_tun/server.go` | App Extension subclassing `NEPacketTunnelProvider` |
| Packet entry | `sing-tun` TUN object and stack | `NEPacketTunnelProvider.packetFlow` |
| Config source | Mihomo YAML and runtime API | System VPN preferences via containing app |
| Lifecycle | Mihomo process and config reload | System-managed extension lifecycle |
| macOS interface naming | `utunN` enforced in source | System-managed virtual interface |
| Route model | `auto-route`, route include/exclude fields | `includedRoutes`, `excludedRoutes`, `includeAllNetworks`, `enforceRoutes` |
| DNS model | `dns-hijack` plus resolver blacklist behavior | DNS settings in `NEPacketTunnelNetworkSettings` |
| Permission model | local network/admin privileges depending on platform and mode | entitlement, signing, user approval |
| Reuse potential | proxy-core integration and TUN logic | native lifecycle and system VPN UX |

## Implementation Reference Guidance

### Good To Reference From Mihomo

Reference these when building a related implementation:

- `RawTun` field design and defaults in `config/config.go`
- `parseTun` for config-to-runtime mapping
- `ReCreateTun` for reload-safe listener lifecycle
- Darwin `utunN` validation in `listener/sing_tun/server.go`
- fd handoff handling through `file-descriptor`
- DNS hijack expansion in `sing_tun.New`
- `tun.Options` assembly
- `tun.NewStack` integration with Mihomo handler

### Not Enough For Native macOS VPN

Do not claim that Mihomo already provides a macOS native Packet Tunnel Provider.

Missing native pieces:

- Xcode App target
- Packet Tunnel Provider extension target
- NetworkExtension entitlement and signing
- `NETunnelProviderManager` configuration flow
- `NEPacketTunnelProvider.startTunnel` / `stopTunnel`
- `NEPacketTunnelNetworkSettings`
- `packetFlow` adapter

### Recommended Architecture For A Native Wrapper

```text
macOS containing app
  -> manages UI and config
  -> uses NETunnelProviderManager
  -> starts/stops VPN configuration

Packet Tunnel Provider extension
  -> sets NEPacketTunnelNetworkSettings
  -> reads/writes packetFlow
  -> bridges packets to Mihomo core or a compatible adapter

Mihomo Go core
  -> parses rules/proxies/DNS
  -> performs tunnel routing
  -> uses outbound adapters
```

### fd Route

If a native layer can provide a usable utun fd, inspect:

```text
config/config.go
listener/config/tun.go
listener/inbound/tun.go
listener/sing_tun/server.go
listener/sing_tun/tun_name_darwin.go
```

The repo can pass `FileDescriptor` into `sing-tun`. On Darwin it can query the real utun name from the fd.

Risk: `NEPacketTunnelProvider.packetFlow` is an object API, not guaranteed to expose a transferable fd. If no fd is available, a packetFlow-to-core adapter is required.

## Answer Templates

### If asked "does Mihomo use macOS native VPN?"

Answer:

Mihomo uses a TUN listener built on `sing-tun`; on macOS it handles `utunN` naming and can accept a TUN file descriptor. This repository does not implement `NEPacketTunnelProvider` or `NETunnelProviderManager`, so it is not a complete Apple NetworkExtension VPN app.

### If asked "can I reference it?"

Answer:

Yes, reference Mihomo for TUN config design, route/DNS options, stack startup, listener lifecycle, and integration into the proxy core. For a native macOS VPN app, also implement a NetworkExtension containing app and Packet Tunnel Provider, then bridge `packetFlow` or an external TUN fd into the Mihomo core.

### If asked "which path should I choose?"

Answer:

Use Mihomo's current TUN path for CLI/core/router-style usage. Use NetworkExtension Packet Tunnel when the target is a signed native macOS VPN app with system-managed VPN lifecycle. Use system proxy or App Proxy only when flow-level proxying is enough and raw IP packet capture is not required.

## Cross References

- [[source-map]]
- [[runtime-flows]]
- [[config-reference]]
- [[config-field-index]]
- [[development-recipes]]
- [[debugging-playbook]]
- [[glossary]]
