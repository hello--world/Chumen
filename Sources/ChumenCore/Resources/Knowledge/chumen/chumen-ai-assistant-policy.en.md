---
title: "Chumen Assistant Policy"
tags: ["chumen", "ai", "assistant", "ollama", "review", "security"]
created: 2026-07-05T14:30:00Z
updated: 2026-07-05T14:30:00Z
sources:
  - docs/security-model.en.md
  - DESIGN.en.md
  - Sources/ChumenCore/ChumenAI.swift
  - Sources/ChumenMacApp/AIAssistantOverlayView.swift
  - Sources/ChumenMacApp/AppModel.swift
links:
  - chumen-ai-assistant-policy.zh.md
  - chumen-knowledge-routing.en.md
category: reference
confidence: high
schemaVersion: 1
---

# Chumen Assistant Policy

中文版本: [chumen-ai-assistant-policy.zh.md](chumen-ai-assistant-policy.zh.md)

## Provider Model

- Local Ollama is the preferred default path at `http://127.0.0.1:11434/v1`.
- Local Ollama does not require an API key.
- Local model names come from Ollama `/api/tags`; users may also type a model name manually.
- Custom OpenAI-compatible endpoints require base URL, model name, and key.
- Keys are stored in Keychain and must not appear in logs, plaintext UI, notifications, or command output.
- Without a usable model, the assistant entry may fall back to local search.

## Output Protocol

Model output should be JSON:

- `reply`: short user-facing explanation.
- `changes`: reviewable proposed changes.

Allowed change kinds:

- `importSubscription`
- `setMode`
- `setTun`
- `setSystemProxy`
- `setConfigAppendix`
- `reloadRuntimeConfig`

All changes must enter the review queue first. The app must not mutate config or runtime state before the user applies a proposal.

## Local Help Routing

Tutorial questions should prefer the Chumen app knowledge base and do not need a model or core API. Examples:

- How do I add a proxy?
- How do I import a subscription?
- How do I add a rule?
- What are prepend and append?

These answers must explain entry point, steps, and activation conditions. They must not collapse to only "could not connect to core API".

Concrete draft requests should still go to the model, for example: "add a vless node with server 1.1.1.1 and port 443".

## Runtime Questions

Questions about current proxy lists, active connections, current rules, traffic, memory, provider state, DNS query, or raw API depend on the core API. If the API is unreachable, explain that the core must be started or the controller port checked.

## Review Boundary

The assistant must:

- Say changes are waiting for review, not already applied.
- Provide git-like inspectable diffs.
- Avoid destructive delete operations.
- Keep replies short, usually at most 4 bullets.
- Reply in the current UI language unless the user asks otherwise.

The assistant must not:

- Auto-apply config.
- Auto-toggle system proxy or TUN.
- Auto-import subscriptions.
- Output API keys, PINs, controller secrets, age private keys, decrypted profiles, or credential-bearing subscription URLs.

## Relationship To Knowledge Bases

The Chumen app knowledge base answers "how to use Chumen". The mihomo knowledge base answers "how to write the fields". If both are relevant, explain the Chumen entry point first, then use mihomo field details.
