---
title: "Chumen Application Knowledge Base"
tags: ["chumen", "application", "assistant", "profiles", "workflow", "knowledge-base"]
created: 2026-07-05T14:20:01Z
updated: 2026-07-05T14:20:01Z
sources:
  - README.en.md
  - DESIGN.en.md
  - docs/security-model.en.md
  - docs/ui-design-system.en.md
  - Sources/ChumenCore/ChumenAI.swift
  - Sources/ChumenMacApp/AppModel.swift
links:
  - chumen-application-knowledge-base.zh.md
  - chumen-engineering-operating-constraints.md
category: reference
confidence: high
schemaVersion: 1
---

# Chumen Application Knowledge Base

中文版本: [chumen-application-knowledge-base.zh.md](chumen-application-knowledge-base.zh.md)

## Positioning

Chumen is a native macOS SwiftUI app for starting, controlling, and observing a local mihomo core. Chumen owns app navigation, the profile library, runtime config generation, security protection, system proxy control, the TUN helper, dashboard surfaces, logs, AI review proposals, and menu bar lifecycle. mihomo owns proxy protocols, configuration field semantics, and the controller API.

## Related Pages

- [[chumen-knowledge-routing.en]]: what to read first and the Chumen/mihomo knowledge boundary.
- [[chumen-profile-workflows.en]]: profiles, subscriptions, nodes, rules, proxy groups, and append overlays.
- [[chumen-runtime-and-system.en]]: core lifecycle, system proxy, TUN, ports, and state ownership.
- [[chumen-ai-assistant-policy.en]]: assistant provider model, review proposals, and local help routing.
- [[chumen-troubleshooting.en]]: core API, config activation, system proxy, TUN, and AI-answer troubleshooting.

Knowledge boundaries:

- The Chumen app knowledge base answers app questions such as where to click, how to add or apply something, why review is required, and why PIN/TUN/helper behavior exists.
- The mihomo knowledge base answers core/protocol questions such as YAML field syntax, protocol-specific fields, and controller endpoint behavior.
- "Could not connect to core API" affects live runtime state, proxy lists, connections, rules, traffic, and core tools. It must not block configuration tutorials, knowledge answers, or offline profile editing guidance.

## Information Architecture

Main screens:

- Dashboard: runtime status, core quick actions, key metrics, modular dashboard items, and the AI assistant.
- Config: profile library, subscription import, local YAML import, activation, update, editing, and append overlays.
- Proxies: proxy groups, node selection, delay checks, and clearing pinned selections.
- Provider: proxy-provider and rule-provider lists, update, and health checks.
- Connections: connection list, close actions, and connection analysis.
- Rules: rule list, rule search, match testing, enable/disable actions.
- Core: mihomo/runtime settings such as ports, TUN, DNS, listeners, and log level.
- Core Tools: reload/patch config, kernel restart, DNS/fake-IP/cache/storage/raw API tools.
- Logs: app logs, core logs, and issue analysis.
- Settings: Chumen preferences, menu bar, sync, security, and AI provider settings.

## Config And Runtime Model

Chumen maintains a profile library and generates the final runtime YAML for mihomo.

- Original profiles come from local YAML files, remote subscriptions, or imports from other clients.
- Profiles and the profile library are age-protected by default.
- Runtime YAML generation overrides Chumen-owned values such as ports, controller, secret, mode, TUN, DNS, listeners, allow-lan, IPv6, external UI, CORS, and hosts.
- Append overlays are a Chumen profile extension, not native mihomo fields. Chumen merges them into standard mihomo YAML during runtime generation.
- A running core can reload through the controller. If the core is stopped, config changes take effect the next time it starts.

## Append Overlay Protocol

Append overlays add or remove list entries without modifying the original subscription/profile file. Supported sections:

- `proxies`
- `proxy-groups`
- `rules`

Operations:

- `prepend`: place entries before the original list, useful for higher-priority rules or nodes.
- `append`: place entries after the original list, useful for supplemental nodes, rules, or groups.
- `delete`: remove original list entries by full rule line or by node/proxy-group name.

The GUI should make it clear that this is an append overlay, not direct mutation of the original subscription file.

## Common Workflows

### Add A Proxy Node

Adding a proxy is a profile editing task and does not require the core API first.

1. Open Config.
2. Choose the target profile and open Edit Nodes.
3. In the append overlay, choose prepend or append.
4. Fill name, node type, server, port, and protocol-specific fields.
5. Node type and port must accept custom typed values, not only preset selections.
6. Save, then apply or reload the runtime config. If the core is stopped, the change takes effect on next start.

If the user has a subscription URL, prefer importing the subscription. If traffic should use the new node, also add it to a proxy group and adjust rules.

### Add A Rule

1. Open Config and edit the target profile's rules.
2. Choose `prepend`, `append`, or `delete`.
3. Use the form to select or type rule type, match content, and target policy.
4. Target policy should prefer current proxy groups plus built-ins such as `DIRECT`, `REJECT`, `REJECT-DROP`, and `PASS`, while still accepting custom input.
5. Save, then apply or reload.

Rule-page search and match testing are runtime aids. Profile editing itself does not depend on the core API.

### Add A Proxy Group

1. Open Config and use Edit Proxy Groups.
2. Fill the name and group type such as `select`, `url-test`, `fallback`, or `load-balance`; custom group types must be allowed.
3. Select members from existing nodes, proxy groups, and built-ins, while allowing typed custom values.
4. Save, then apply or reload.

### Toggle System Proxy

System proxy is external macOS state managed through `networksetup`. It is app-level state and should be refreshed by the shared update coordinator. Stopping the core may clear system proxy state according to user settings.

### Toggle TUN

TUN is startup-level configuration. Changing it while running requires a core restart, and macOS may require the privileged helper. On app quit, Chumen must stop the core it started and clean TUN/system proxy state according to settings to avoid leftovers.

## Assistant Boundaries

The assistant may:

- Answer Chumen usage questions and mihomo configuration questions.
- Draft reviewable configuration changes.
- Propose importing subscriptions, changing mode, toggling TUN, toggling system proxy, appending YAML, or reloading runtime config.

The assistant must not:

- Mutate config or runtime state before the user applies a proposal.
- Claim a change has already been applied unless the app actually completed the operation.
- Answer tutorial questions only with "could not connect to core API".
- Log or display API keys, PINs, age private keys, controller secrets, credential-bearing subscription URLs, or decrypted profile contents.

For tutorial questions such as "how do I add a proxy", "how do I write a rule", or "how do I import a subscription", answer from the Chumen app knowledge base first. Depend on the core API only when the user explicitly asks for live proxy lists, connections, rules, traffic, core tools, or diagnostics.

## Error Interpretation

- Could not connect to core API: the live controller is unreachable. This affects runtime state and core tools, not profile editing tutorials.
- Core not running: proxy, connection, rule, traffic, and memory runtime data are unavailable.
- External core detected: the controller responds, but the process was not started by Chumen. Chumen may read state, but should not take over stop/restart semantics.
- Config protection/PIN issues: see `docs/security-model.en.md`; PIN protection is not the same as app lock.

## External mihomo Knowledge Sources

If present on the machine, these paths can be used as mihomo core knowledge sources:

- `/Volumes/SanDisk/code/mihomo/docs/human`
- `/Volumes/SanDisk/code/mihomo/omx_wiki`

Integration guidance:

- Do not hardcode absolute disk paths in the app.
- Build/import should copy or index them into Chumen-owned knowledge storage.
- Chumen app knowledge decides what the user should do in the app; mihomo knowledge supplies field-level details.
