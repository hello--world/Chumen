---
title: "Chumen Knowledge Routing"
tags: ["chumen", "knowledge-base", "routing", "mihomo", "assistant"]
created: 2026-07-05T14:30:00Z
updated: 2026-07-05T14:30:00Z
sources:
  - omx_wiki/chumen-application-knowledge-base.en.md
  - README.en.md
  - DESIGN.en.md
  - /Volumes/SanDisk/code/mihomo/docs/human/README.md
  - /Volumes/SanDisk/code/mihomo/omx_wiki/index.md
links:
  - chumen-knowledge-routing.zh.md
  - chumen-application-knowledge-base.en.md
  - chumen-profile-workflows.en.md
  - chumen-runtime-and-system.en.md
  - chumen-ai-assistant-policy.en.md
  - chumen-troubleshooting.en.md
category: reference
confidence: high
schemaVersion: 1
---

# Chumen Knowledge Routing

中文版本: [chumen-knowledge-routing.zh.md](chumen-knowledge-routing.zh.md)

## Completeness Criteria

The Chumen knowledge base must answer five classes of questions:

1. App entry points: which page and which button the user needs.
2. Config workflows: import, edit, append overlays, apply, and reload.
3. Runtime state: which facts require the core API and which are offline Chumen state.
4. Security and AI: which operations require review and which secrets must never be exposed.
5. Troubleshooting: what common errors mean and where to inspect next.

If the question is about mihomo YAML fields, proxy protocol details, controller API endpoints, or core source code, route to the mihomo knowledge base.

## Query Routing

| User asks about | Read first |
| --- | --- |
| What Chumen is and which screens exist | [[chumen-application-knowledge-base.en]] |
| How to add proxies, rules, groups, or subscriptions | [[chumen-profile-workflows.en]] |
| How prepend/append/delete overlays work | [[chumen-profile-workflows.en]] |
| Start/stop/restart, system proxy, TUN, ports | [[chumen-runtime-and-system.en]] |
| Which state requires the core API | [[chumen-runtime-and-system.en]] |
| How the assistant should answer or whether it may mutate config | [[chumen-ai-assistant-policy.en]] |
| Core API unavailable, config not taking effect, TUN failure | [[chumen-troubleshooting.en]] |
| mihomo config fields, protocol fields, controller API | `/Volumes/SanDisk/code/mihomo/omx_wiki/index.md` |
| mihomo onboarding and source learning | `/Volumes/SanDisk/code/mihomo/docs/human/README.md` |

## Answering Strategy

- First classify the question as Chumen app operation or mihomo core detail.
- App-operation questions must not collapse to only "could not connect to core API".
- When YAML is needed, explain the Chumen entry point and review/apply path before field-level mihomo details.
- For live runtime state, state that the core API must be online.
- For security, config writes, system proxy, TUN, and subscription import, preserve the review/apply boundary.

## External mihomo Knowledge Integration

Available local paths:

- `/Volumes/SanDisk/code/mihomo/docs/human`
- `/Volumes/SanDisk/code/mihomo/omx_wiki`

These are suitable for the development environment, not for hardcoding into a released Chumen build. Release or sync flows should copy them into Chumen-owned storage or expose a user-configurable knowledge path.
