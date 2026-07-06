---
title: Mihomo Documentation Audit
category: reference
tags: [documentation, audit, clarity, coverage]
source_files: [docs/README.md, docs/human/README.md, omx_wiki/index.md, main.go, config/config.go, hub/route/server.go, Makefile]
status: current
---

# Mihomo Documentation Audit

This page records the current coverage and known boundaries of the human docs and AI knowledge base.

## Audit Goal

The documentation should support two users:

1. A beginner human reader who needs a clear learning path.
2. An AI agent that needs stable source anchors, query routing, and append rules.

## Current Human Docs Coverage

| Area | Status | Human entry |
| --- | --- | --- |
| First build and run | Covered | `docs/human/01-first-run-and-mental-model.md` |
| Mental model | Covered | `docs/human/01-first-run-and-mental-model.md` |
| Source directory map | Covered | `docs/human/02-source-map-and-startup.md` |
| Startup flow | Covered | `docs/human/02-source-map-and-startup.md` |
| Config parse flow | Covered | `docs/human/03-config-to-runtime.md` |
| TCP/UDP lifecycle | Covered | `docs/human/04-traffic-lifecycle.md` |
| Development recipes | Covered | `docs/human/05-development-recipes.md` |
| Debugging and FAQ | Covered | `docs/human/06-debugging-and-faq.md` |
| Learning self-check | Covered | `docs/human/07-reading-checklist-and-ai-questions.md` |
| TUN and macOS native networking | Covered | `docs/human/08-tun-and-macos-native-networking.md` |

## Current AI KB Coverage

| Area | Status | AI entry |
| --- | --- | --- |
| Query routing | Covered | [[index]] |
| Architecture overview | Covered | [[mihomo-overview]] |
| Source map | Covered | [[source-map]] |
| Runtime flows | Covered | [[runtime-flows]] |
| Config parse reference | Covered | [[config-reference]] |
| Config field ownership | Covered | [[config-field-index]] |
| API route map | Covered | [[api-route-map]] |
| Build/test/CI matrix | Covered | [[build-test-matrix]] |
| Development recipes | Covered | [[development-recipes]] |
| Debugging playbook | Covered | [[debugging-playbook]] |
| Glossary | Covered | [[glossary]] |
| Append protocol | Covered | [[append-protocol]] |
| TUN, macOS utun, NetworkExtension comparison | Covered | [[tun-macos-native]] |

## Deliberate Boundaries

The docs intentionally do not fully expand:

- every outbound protocol handshake
- every transport encryption detail
- every platform-specific TUN/TPROXY syscall path beyond the macOS TUN overview in [[tun-macos-native]]
- every REST response schema
- every YAML option as an end-user manual
- every provider file format example

Reason: those areas are large and change-prone. The current documentation instead gives source anchors and expansion protocols.

## High-Value Future Additions

If future users ask more detailed questions, add focused pages:

| Trigger | Suggested page |
| --- | --- |
| repeated questions about DNS | `dns-deep-dive.md` |
| repeated questions about provider update behavior | `provider-deep-dive.md` |
| repeated questions about Linux TUN/TPROXY | `tun-transparent-proxy.md` |
| repeated questions about rule syntax | `rule-type-reference.md` |
| repeated questions about API JSON | `api-schema-reference.md` |
| repeated questions about a protocol | `protocol-<name>.md` |

## Clarity Checklist For New Pages

Every new doc page should answer:

1. What problem does this page solve?
2. Which source files prove the facts?
3. What is the main flow in 5 to 10 steps?
4. What terms will confuse a beginner?
5. What should an AI agent inspect before answering?
6. What is outside the page boundary?

## Last Audit Result

The original split docs covered the main architecture but were weak in four machine-readable areas:

- API route inventory
- config field ownership index
- build/test/CI matrix
- explicit reader self-check and AI prompt guidance

Those areas are now covered by:

- [[api-route-map]]
- [[config-field-index]]
- [[build-test-matrix]]
- `docs/human/07-reading-checklist-and-ai-questions.md`
