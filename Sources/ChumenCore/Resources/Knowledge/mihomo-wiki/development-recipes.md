---
title: Mihomo Development Recipes
category: pattern
tags: [development, recipe, add-rule, add-proxy, add-listener, add-api]
source_files: [rules/parser.go, adapter/parser.go, listener/parse.go, hub/route/server.go, config/config.go]
status: current
---

# Mihomo Development Recipes

## Add A Rule Type

Use when user asks to support a new rule such as `FOO,payload,target`.

Steps:

1. Add implementation under `rules/common/`.
2. Implement the required `constant.Rule` behavior.
3. Add switch branch in `rules/parser.go`.
4. Use `RuleMatchHelper.ResolveIP` only when IP resolution is needed.
5. Use `RuleMatchHelper.FindProcess` only when process lookup is needed.
6. Add tests under `rules/` or related package.
7. Run `go test ./rules/...`.

Do not perform unconditional DNS or process lookups in rule matching.

## Add An Outbound Proxy Type

Steps:

1. Add file in `adapter/outbound/`.
2. Define option schema.
3. Implement `constant.ProxyAdapter`.
4. Add lower protocol code in `transport/<protocol>/` if needed.
5. Add `type` branch in `adapter/parser.go`.
6. Return `adapter.NewProxy` through normal parse flow.
7. Add unit and integration tests where possible.

Minimum methods to verify:

```text
Name
Type
Addr
SupportUDP
DialContext
ListenPacketContext
SupportUOT
IsL3Protocol
Unwrap
Close
MarshalJSON
```

Reference files:

- Simple: `adapter/outbound/direct.go`
- Medium: `adapter/outbound/http.go`
- Complex: `adapter/outbound/vless.go`

## Add An Inbound Listener Type

For `listeners:` array support:

1. Add implementation in `listener/inbound/`.
2. Implement `C.InboundListener`.
3. Add branch in `listener/parse.go`.
4. `Listen(tunnel)` must call:
   - TCP: `tunnel.HandleTCPConn`
   - UDP: `tunnel.HandleUDPPacket`
5. Add tests.

For top-level port support:

1. Add fields to `RawConfig`.
2. Add fields to `General` or `Inbound`.
3. Update `parseGeneral`.
4. Update `executor.updateListeners`.
5. Add `listener.ReCreateXxx`.

## Add A Config Field

Steps:

1. Add YAML field to `RawConfig`.
2. Add default in `DefaultRawConfig` if needed.
3. Parse into runtime config.
4. Add target field in `Config` or child struct.
5. Apply in `executor.ApplyConfig`.
6. Update API output if relevant.
7. Add tests.

Questions to answer:

- Does this field need hot reload?
- Does it create or close resources?
- Does it involve safe paths?
- Does it affect every request?

## Add A REST API Endpoint

Steps:

1. Find matching `hub/route/*.go`.
2. Register route in router function.
3. Use existing auth and render conventions.
4. For writes, consider locks and runtime state.
5. Avoid bypassing `executor.ApplyConfig` for config mutations unless there is a strong reason.

Top-level route mounting is in `hub/route/server.go`.

## High Risk Areas

| Area | Risk |
| --- | --- |
| `tunnel/` | Every TCP/UDP flow, concurrency, NAT, retries |
| `dns/` and `component/resolver/` | fake-ip, host restoration, rule behavior |
| `listener/sing_tun` and `listener/tproxy` | Platform and privilege sensitive |
| `component/resource` | Provider cache, update loops, backoff |
| `adapter/outboundgroup` | Selection behavior affects many users |

## Verification Suggestions

| Change | Commands |
| --- | --- |
| Docs only | `bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-learning -t -f docs/learning-minimal.yaml` |
| Config parsing | `go test ./config ./constant ./rules/...` |
| Rules | `go test ./rules/...` |
| Common utilities | `go test ./common/...` |
| Tunnel/listener | `go test ./tunnel ./listener/...` then `go test ./...` |
| Protocol | `go test ./adapter/outbound/... ./transport/<protocol>/...` and `cd test && make test` |
