---
title: Mihomo Glossary
category: reference
tags: [glossary, terms, definitions]
source_files: [constant/metadata.go, constant/adapters.go, constant/tunnel.go, tunnel/mode.go]
status: current
---

# Mihomo Glossary

## Terms

| Term | Definition |
| --- | --- |
| listener | Inbound component that accepts local traffic and sends it to tunnel |
| inbound | Same direction as listener: local traffic entering Mihomo |
| outbound | Direction from Mihomo to destination or upstream proxy |
| adapter | Unified outbound proxy abstraction |
| proxy | Concrete outbound or proxy group object |
| proxy group | Outbound group such as select, url-test, fallback, load-balance |
| tunnel | Core runtime that handles TCP/UDP routing decisions |
| Metadata | Per-flow or per-packet context: host, IP, port, type, process, user |
| rule | Matcher that selects target proxy name from Metadata |
| provider | Remote/local/inline source of proxies or rules |
| vehicle | Resource backend for provider: file or http |
| fake-ip | DNS mode mapping fake IPs back to domains |
| sniffer | Component that extracts host info from traffic |
| direct | Outbound mode or proxy that connects directly |
| global | Mode that routes all traffic to GLOBAL |
| rule mode | Mode that routes traffic by rules |
| controller | RESTful API service |
| external-ui | Web UI static file directory |
| TUN | Virtual network interface inbound |
| utun | macOS virtual network interface name family used for TUN-like interfaces, usually `utunN` |
| sing-tun | External dependency used by Mihomo to create/manage TUN interfaces and IP stacks |
| NetworkExtension | Apple framework for VPN, app proxy, DNS proxy, filtering and related network extensions |
| Packet Tunnel Provider | Apple NetworkExtension app extension that handles IP packets through `NEPacketTunnelProvider.packetFlow` |
| TProxy | Transparent proxy mechanism, mostly Linux |
| redir | Redirect proxy inbound |

## Enums

Tunnel modes from `tunnel/mode.go`:

| Mode | Meaning |
| --- | --- |
| `direct` | All traffic uses DIRECT |
| `global` | All traffic uses GLOBAL |
| `rule` | Traffic is matched by rules |

Tunnel statuses from `tunnel/status.go`:

| Status | Meaning |
| --- | --- |
| `suspend` | Not handling normal traffic |
| `inner` | Handling inner traffic only |
| `running` | Normal runtime |

Network from `constant/metadata.go`:

| Value | Meaning |
| --- | --- |
| TCP | TCP flow |
| UDP | UDP packet/session |
| ALLNet | Used for rules/options matching both |

## Beginner Explanation

Use this analogy for humans:

```text
listener is the door.
Metadata is the delivery label.
tunnel is the sorting center.
rules are the sorting rules.
adapter is the delivery route.
transport is the vehicle details.
```

Do not overuse analogies in technical answers. Use them only when the user is a beginner.
