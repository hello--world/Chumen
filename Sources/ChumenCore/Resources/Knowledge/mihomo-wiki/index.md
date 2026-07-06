---
title: Mihomo AI Knowledge Base Index
category: reference
tags: [index, ai, knowledge-base, mihomo]
status: current
---

# Mihomo AI Knowledge Base Index

This wiki is optimized for AI agents that need to answer questions about this repository and append new project knowledge.

Use this page first. Then route to the page matching the user's question.

## Query Routing

| User asks about | Read first |
| --- | --- |
| What is this project, high level architecture | [[mihomo-overview]] |
| Which file implements something | [[source-map]] |
| Startup, config reload, lifecycle | [[runtime-flows]] |
| YAML config, field flow, parse order | [[config-reference]] |
| Which config field belongs to which subsystem | [[config-field-index]] |
| TCP/UDP request path, Metadata, rules | [[runtime-flows]] |
| TUN, macOS utun, NetworkExtension, Packet Tunnel Provider | [[tun-macos-native]] |
| REST API routes, external controller, endpoint additions | [[api-route-map]] |
| Adding rules, proxy, listener, API, config field | [[development-recipes]] |
| Build, tests, CI, local commands | [[build-test-matrix]] |
| Error troubleshooting | [[debugging-playbook]] |
| Whether the docs cover a topic or what to add next | [[documentation-audit]] |
| Terms like listener, adapter, tunnel, provider | [[glossary]] |
| How to add or update this KB | [[append-protocol]] |

## Page List

- [[mihomo-overview]] - Canonical architecture summary.
- [[source-map]] - Directory and file ownership map.
- [[runtime-flows]] - Startup, config application, TCP and UDP flows.
- [[tun-macos-native]] - TUN implementation, macOS `utunN`, and NetworkExtension comparison.
- [[config-reference]] - Config parse order and field-to-runtime mappings.
- [[config-field-index]] - YAML field ownership and subsystem routing.
- [[api-route-map]] - External controller and REST API route map.
- [[build-test-matrix]] - Build targets, feature tags, CI and validation commands.
- [[development-recipes]] - Step-by-step implementation recipes.
- [[debugging-playbook]] - Build, test, validation and troubleshooting.
- [[documentation-audit]] - Coverage map, deliberate boundaries and future additions.
- [[glossary]] - Stable definitions of project terms.
- [[append-protocol]] - How AI agents should append, update and cite knowledge.
- [[log]] - Chronological KB maintenance log.

## Answering Policy For AI Agents

When answering:

1. Prefer facts from this wiki and the repository source.
2. Cite concrete source files when possible.
3. If a fact may have changed, inspect the repository before answering.
4. Do not invent unsupported behavior.
5. Distinguish evidence from inference.
6. If adding knowledge, follow [[append-protocol]].

## Canonical One-Sentence Summary

Mihomo is a Go proxy core that receives local traffic through listeners, converts it into Metadata, routes it through tunnel and rules, selects an outbound adapter, and forwards TCP/UDP traffic to the final destination or upstream proxy.
