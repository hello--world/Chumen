---
title: Mihomo Debugging Playbook
category: debugging
tags: [debugging, testing, troubleshooting, build]
source_files: [Makefile, .github/workflows/test.yml, .github/workflows/build.yml, test/README.md, tunnel/tunnel.go]
status: current
---

# Mihomo Debugging Playbook

## Build Commands

```sh
go build -tags with_gvisor
make darwin-arm64
make linux-amd64-v3
make windows-amd64-v3
```

The Makefile uses:

```text
CGO_ENABLED=0 go build -tags with_gvisor -trimpath -ldflags ...
```

## Minimal Config Validation

```sh
bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-learning -t -f docs/learning-minimal.yaml
```

Expected:

```text
configuration file .../docs/learning-minimal.yaml test is successful
```

## Unit Tests

```sh
go test ./...
go test ./... -tags "with_gvisor" -count=1
```

CI tests Go 1.20 through 1.26 across Linux, macOS and Windows variants.

## Integration Tests

`test/` is a separate Go module and expects Docker.

```sh
cd test
make test
```

This runs:

```sh
go test -p 1 -v ./...
```

## Troubleshooting Matrix

| Symptom | Inspect |
| --- | --- |
| Config parse fails | `config/config.go`, exact error text |
| Port not listening | `listener/listener.go`, `allow-lan`, `bind-address`, port value |
| Rule not effective | `mode`, rules order, `tunnel.match`, target proxy existence |
| UDP not working | `SupportUDP`, `tunnel.handleUDPConn`, NAT table |
| Provider empty | provider URL, filter, exclude-filter, path safety |
| API unauthorized | `secret`, Authorization header |
| Safe path error | `constant/path.go`, `-d`, `SAFE_PATHS` |
| DNS/fake-ip issue | `preHandleMetadata`, `component/fakeip`, `component/resolver` |
| SIGHUP reload issue | `hub.Parse`, `executor.ApplyConfig`, listener recreate functions |

## Rule Debugging

Check:

1. `mode: rule`.
2. `MATCH` is last.
3. Target proxy or group exists.
4. For domain rules, host or sniff host is available.
5. For IP rules, DNS resolution is available.
6. For process rules, process lookup mode allows it.

Source:

- `rules/parser.go`
- `tunnel.match`
- `constant/rule.go`

## UDP Debugging

Check:

1. Inbound supports UDP.
2. Rule target supports UDP.
3. `adapter.SupportUDP()` result.
4. NAT table cleanup and timeouts.
5. Logs for "UDP is not supported".

Source:

- `tunnel.HandleUDPPacket`
- `tunnel.handleUDPConn`
- `tunnel/connection.go`

## Provider Debugging

Check:

1. `type`: file/http/inline.
2. `path`: safe path.
3. `url`: reachable.
4. `proxy`: needed for download or not.
5. `filter`: not filtering all nodes.
6. `size-limit`: not too small.
7. `behavior` and `format` for rule provider.

Source:

- `adapter/provider/parser.go`
- `rules/provider/parse.go`
- `component/resource/fetcher.go`
- `component/resource/vehicle.go`

## API Debugging

Enable:

```yaml
external-controller: 127.0.0.1:9090
secret: test
```

Use:

```sh
curl -H 'Authorization: Bearer test' http://127.0.0.1:9090/version
curl -H 'Authorization: Bearer test' http://127.0.0.1:9090/proxies
curl -H 'Authorization: Bearer test' http://127.0.0.1:9090/rules
curl -H 'Authorization: Bearer test' http://127.0.0.1:9090/connections
```

Source:

- `hub/route/server.go`
- `hub/route/*.go`

## Log Interpretation

`tunnel.logMetadata` formats traffic logs like:

```text
[TCP] source --> target match RULE(payload) using chain
[UDP] source --> target using chain
```

If no rule matched:

```text
doesn't match any rule using DIRECT
```
