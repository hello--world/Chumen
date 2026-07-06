---
title: Mihomo KB Log
category: session-log
tags: [log, wiki, maintenance]
status: current
---

# Mihomo KB Log

## 2026-07-04 - Initial AI Knowledge Base

- Changed: created `omx_wiki` with index, architecture overview, source map, runtime flows, config reference, development recipes, debugging playbook, glossary and append protocol.
- Evidence: repository source inspection of `main.go`, `config/config.go`, `hub/hub.go`, `hub/executor/executor.go`, `listener/listener.go`, `adapter/parser.go`, `rules/parser.go`, `tunnel/tunnel.go`, `dns/server.go`, `component/resource/*`.
- Reason: user requested documentation that works both for humans and AI agents as a maintainable knowledge base.

## 2026-07-04 - Documentation Audit Expansion

- Changed: added [[api-route-map]], [[config-field-index]], [[build-test-matrix]] and [[documentation-audit]].
- Changed: added `docs/human/07-reading-checklist-and-ai-questions.md`.
- Evidence: checked `hub/route/*.go`, `config/config.go`, `adapter/parser.go`, `listener/parse.go`, `adapter/outboundgroup/parser.go`, `Makefile`, `.github/workflows/test.yml` and existing documentation headings.
- Reason: user requested a stricter review for omissions and clarity, with the goal of the clearest possible project organization.

## 2026-07-04 - TUN And macOS Native Networking

- Changed: added [[tun-macos-native]] and `docs/human/08-tun-and-macos-native-networking.md`.
- Changed: updated human doc indexes, source map, config field index, glossary and documentation audit.
- Evidence: checked `config/config.go`, `constant/tun.go`, `listener/listener.go`, `listener/sing_tun/server.go`, `listener/sing_tun/tun_name_darwin.go`, `listener/inbound/tun.go`, `docs/config.yaml`, `go.mod`, Apple NetworkExtension docs and Apple SimpleTunnel sample.
- Reason: user asked how Mihomo's TUN differs from macOS native networking technologies and whether the implementation can be used as a reference.
