---
title: Mihomo Source Map
category: reference
tags: [source-map, files, modules, ownership]
source_files: [main.go, Makefile, config/config.go, listener/listener.go, listener/sing_tun/server.go, listener/sing_tun/tun_name_darwin.go, adapter/parser.go, rules/parser.go, tunnel/tunnel.go]
status: current
---

# Mihomo Source Map

## Directory Map

| Path | Ownership |
| --- | --- |
| `main.go` | Process entrypoint, CLI, lifecycle |
| `Makefile` | Local cross-platform builds |
| `.github/workflows/test.yml` | CI test matrix |
| `.github/workflows/build.yml` | Release build matrix |
| `config/` | Config parsing and defaults |
| `constant/` | Shared interfaces, enums, Metadata, path logic |
| `hub/` | Runtime config application and API bootstrap |
| `hub/executor/` | Runtime update sequencing |
| `hub/route/` | RESTful API endpoints |
| `listener/` | Built-in inbound listener lifecycle |
| `listener/inbound/` | Config-driven inbound listener objects |
| `listener/sing_tun/` | TUN listener integration, sing-tun options, macOS utun handling |
| `adapter/` | Outbound proxy wrapper and parser |
| `adapter/outbound/` | Concrete outbound proxy implementations |
| `adapter/outboundgroup/` | Proxy group implementations |
| `adapter/provider/` | Proxy provider parsing and loading |
| `rules/` | Rule parser and rule objects |
| `rules/provider/` | Rule provider parsing and loading |
| `tunnel/` | Core TCP/UDP routing and relay |
| `dns/` | DNS service, server, resolver construction |
| `component/` | Shared components such as resolver, fakeip, resource |
| `transport/` | Protocol transport implementations |
| `common/` | Utility packages and network primitives |
| `test/` | Docker-backed protocol integration tests |
| `docs/` | Human documentation |
| `omx_wiki/` | AI-readable knowledge base |

## Key Files By Question

| Question | File |
| --- | --- |
| Where does startup begin? | `main.go` |
| Where are CLI flags registered? | `main.go` |
| Where is YAML parsed? | `config/config.go` |
| Where are default config values? | `config/config.go` |
| Where is config applied? | `hub/hub.go`, `hub/executor/executor.go` |
| Where are listeners recreated? | `listener/listener.go` |
| Where is top-level TUN recreated? | `listener/listener.go`, `listener/sing_tun/server.go` |
| Where is macOS utun naming handled? | `listener/sing_tun/server.go`, `listener/sing_tun/tun_name_darwin.go` |
| Where is TUN compared with macOS NetworkExtension? | `omx_wiki/tun-macos-native.md` |
| Where is `listeners:` parsed? | `listener/parse.go` |
| Where are proxies parsed? | `adapter/parser.go` |
| Where are proxy groups parsed? | `adapter/outboundgroup/parser.go` |
| Where are rules parsed? | `rules/parser.go`, `config/config.go` |
| Where is traffic routed? | `tunnel/tunnel.go` |
| Where is Metadata defined? | `constant/metadata.go` |
| Where is ProxyAdapter defined? | `constant/adapters.go` |
| Where is Tunnel interface defined? | `constant/tunnel.go` |
| Where is REST API mounted? | `hub/route/server.go` |
| Where are detailed API routes documented? | `omx_wiki/api-route-map.md` |
| Where is DNS server recreated? | `dns/server.go` |
| Where are provider resources loaded? | `component/resource/fetcher.go`, `component/resource/vehicle.go` |
| Where is safe path logic? | `constant/path.go` |
| Where is build/test behavior summarized? | `omx_wiki/build-test-matrix.md` |
| Where is config field ownership indexed? | `omx_wiki/config-field-index.md` |

## Do Not Start Here For Beginners

Avoid starting with:

- `transport/`
- platform-specific TUN and TProxy files
- protocol encryption internals
- provider update loops

Start with:

```text
main.go
config/config.go
hub/hub.go
hub/executor/executor.go
listener/listener.go
adapter/parser.go
rules/parser.go
tunnel/tunnel.go
```

## Source Search Hints

Use these searches:

```sh
rg -n "func ApplyConfig|func ParseRawConfig|func ReCreateMixed|func ParseProxy|func ParseRule|func handleTCPConn|func handleUDPConn"
rg -n "mixed-port|proxy-groups|rule-providers|external-controller" config docs
rg -n "type ProxyAdapter|type Metadata|type Tunnel interface" constant
rg -n "type RawTun|func parseTun|func ReCreateTun|CalculateInterfaceName|FileDescriptor|utun" config listener constant docs
```
