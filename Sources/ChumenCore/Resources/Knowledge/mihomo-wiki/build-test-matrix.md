---
title: Mihomo Build And Test Matrix
category: environment
tags: [build, test, ci, makefile, tags]
source_files: [Makefile, .github/workflows/test.yml, constant/features/tags.go, test/README.md, test/Makefile]
status: current
---

# Mihomo Build And Test Matrix

Use this page when answering build, CI, local validation, or platform support questions.

## Local Build

The Makefile defines:

```text
GOBUILD=CGO_ENABLED=0 go build -tags with_gvisor -trimpath -ldflags ...
```

Common local targets:

| Target | Output |
| --- | --- |
| `make darwin-arm64` | `bin/mihomo-darwin-arm64` |
| `make darwin-amd64-v3` | `bin/mihomo-darwin-amd64-v3` |
| `make linux-amd64-v3` | `bin/mihomo-linux-amd64-v3` |
| `make linux-arm64` | `bin/mihomo-linux-arm64` |
| `make windows-amd64-v3` | `bin/mihomo-windows-amd64-v3.exe` |
| `make all` | common Linux/macOS/Windows amd64/arm64 targets |
| `make all-arch` | all platform targets listed in Makefile |

The local verified build in this workspace was:

```sh
make darwin-arm64
```

Validated output:

```text
bin/mihomo-darwin-arm64
```

## Build Tags

Source: `constant/features/tags.go`.

Reported feature tags include:

| Tag | Meaning |
| --- | --- |
| `cmfa` | Clash for Android related feature build |
| `with_low_memory` | low-memory build behavior |
| `no_fake_tcp` | fake TCP disabled |
| `no_tailscale` | tailscale support disabled |
| `with_gvisor` | gVisor TUN stack support enabled |

Makefile builds use `-tags with_gvisor` by default.

## Version Metadata

Makefile injects:

```text
github.com/metacubex/mihomo/constant.Version
github.com/metacubex/mihomo/constant.BuildTime
```

Version source depends on branch/tag state:

| Git state | Version value |
| --- | --- |
| branch `Alpha` | `alpha-<short sha>` |
| branch `Beta` | `beta-<short sha>` |
| detached/tag context | `git describe --tags` |
| other branch | `<short sha>` |

## Config Validation

Use `-t` to test config without running long-lived services:

```sh
bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-learning -t -f docs/learning-minimal.yaml
```

Expected success message:

```text
configuration file ... test is successful
```

## Unit Tests

Makefile target:

```sh
make vet
```

This runs:

```sh
go test ./...
```

CI also runs:

```sh
go test ./... -v -count=1
go test ./... -v -count=1 -tags "with_gvisor"
```

## CI Matrix

Source: `.github/workflows/test.yml`.

CI tests these OS targets:

```text
ubuntu-latest
windows-latest
macos-latest
ubuntu-24.04-arm
windows-11-arm
macos-26-intel
```

CI tests Go versions:

```text
1.20, 1.21, 1.22, 1.23, 1.24, 1.25, 1.26
```

CI env:

```text
CGO_ENABLED=0
GOTOOLCHAIN=local
MSYS_NO_PATHCONV=true
```

macOS CI removes `listener/inbound/*_test.go` before unit tests.

## Integration Tests

Protocol integration tests live under `test/`.

Use:

```sh
cd test
make test
```

These tests are Docker-backed and cover protocol behavior such as Shadowsocks, VMess, VLESS, Trojan, Hysteria, Snell, DNS, and Clash behavior.

## Validation Strategy For Changes

| Change type | Minimum validation |
| --- | --- |
| Docs only | Markdown sanity check and config command examples if touched |
| Config parser | `go test ./config/...` and config validation with a sample YAML |
| Rule parser | `go test ./rules/...` |
| Listener | `go test ./listener/...` or targeted package, plus smoke run if possible |
| Outbound protocol | `go test ./adapter/outbound/...`, transport package tests, integration test if available |
| Tunnel | `go test ./tunnel/...` plus at least one TCP and one UDP scenario |
| DNS/fake-ip | `go test ./dns/... ./component/resolver/... ./component/fakeip/...` |
| API | targeted `hub/route` test if present, manual curl smoke test if running controller |

Cross-reference: [[debugging-playbook]], [[development-recipes]].
