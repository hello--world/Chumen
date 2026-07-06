---
title: "Chumen Profile And Append Overlay Workflows"
tags: ["chumen", "profiles", "append-overlay", "proxies", "rules", "proxy-groups"]
created: 2026-07-05T14:30:00Z
updated: 2026-07-05T14:30:00Z
sources:
  - README.en.md
  - Sources/ChumenMacApp/ProfilesView.swift
  - Sources/ChumenMacApp/ProfileYAMLVisualForms.swift
  - Sources/ChumenMacApp/ProfileYAMLVisualEditor.swift
links:
  - chumen-profile-workflows.zh.md
  - chumen-runtime-and-system.en.md
category: reference
confidence: high
schemaVersion: 1
---

# Chumen Profile And Append Overlay Workflows

中文版本: [chumen-profile-workflows.zh.md](chumen-profile-workflows.zh.md)

## Profile Sources

Profiles can come from:

- A new blank profile.
- A local YAML import.
- A remote subscription URL.
- Scanning other clients such as Clash Verge, ClashX, Mihomo Party, or common `.config` directories.

After import, Chumen copies profiles into its own library and deduplicates by content. The profile index and profile files are age-protected by default.

## Main Config Page Actions

- Create profile: create blank YAML and open editing.
- Import local: choose a local YAML file.
- Import subscription: enter subscription URL and optional display name.
- Import from clients: scan common local client data directories.
- Edit: edit full YAML.
- Edit rules: edit only the `rules` append overlay.
- Edit nodes: edit only the `proxies` append overlay.
- Edit proxy groups: edit only the `proxy-groups` append overlay.
- Direct update: redownload a subscription.
- Proxy update: update a subscription through the current proxy.
- Extend/override config: edit Chumen profile appendix.
- Open file: open the profile file location.
- Delete: remove the profile from Chumen's library.

## Append Overlay Protocol

Append overlays affect only Chumen-generated runtime YAML and should not rewrite the original subscription file.

Supported sections:

- `rules`
- `proxies`
- `proxy-groups`

Operations:

- `prepend`: place entries before the original list.
- `append`: place entries after the original list.
- `delete`: remove full rule lines or named entries from the original list.

Activation path:

1. User saves the append overlay.
2. Chumen merges original config and overlays during runtime YAML generation.
3. A running core may reload; if stopped, changes take effect on next start.

## Add A Proxy Node

This is a profile editing task and does not require the core API to be online.

1. Open Config.
2. Choose the target profile.
3. Click Edit Nodes.
4. In quick add, choose `prepend` or `append`.
5. Fill name, node type, server, port, and protocol fields.
6. Node type, port, cipher, and similar fields should allow typed custom input while offering common values.
7. Save, then apply or reload.

Common node fields:

- Common: `name`, `type`, `server`, `port`, `udp`.
- `ss`: `cipher`, `password`.
- `vmess`/`vless`: `uuid`, `tls`, `servername`.
- `trojan`/`hysteria2`: `password`, `tls`, `sni`.
- `http`/`socks5`: `username`, `password`.
- Advanced fields not covered by the form should go into extra fields or advanced YAML.

## Add A Proxy Group

1. Open Config.
2. Choose the target profile and click Edit Proxy Groups.
3. Choose `prepend` or `append`.
4. Fill group name and group type.
5. Add members from existing nodes, existing groups, built-ins such as `DIRECT` or `REJECT`, or typed custom values.
6. For `url-test`, `fallback`, `load-balance`, and similar groups, add test URL, interval, strategy, and related fields.

Proxy groups determine what the user can switch on the Proxies page. A new node that belongs to no group is usually not used by rules.

## Add A Rule

1. Open Config.
2. Choose the target profile and click Edit Rules.
3. Choose `prepend`, `append`, or `delete`.
4. Fill rule type, match value, target policy, and optional args.
5. Target policy should prefer current proxy groups and built-ins, while still allowing typed custom values.

Common rule types:

- `DOMAIN-SUFFIX`
- `DOMAIN`
- `DOMAIN-KEYWORD`
- `IP-CIDR`
- `GEOIP`
- `PROCESS-NAME`
- `MATCH`

Rule order matters. Rules that must win should use `prepend`.

## Delete Original Items

`delete` removes list items from the original config:

- For rules, enter the full rule line.
- For nodes or proxy groups, enter the name.

This is still an append overlay and does not rewrite the original subscription.

## Save And Apply

- Saving forms updates Chumen-managed profile extensions.
- Apply or reload regenerates runtime YAML.
- If the core is running and the API is reachable, reload can be hot.
- If the API is unavailable or the core is stopped, changes remain in the profile library and take effect on next start.
