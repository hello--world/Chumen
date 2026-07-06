---
title: Mihomo API Route Map
category: reference
tags: [api, route, controller, restful, hub]
source_files: [hub/route/server.go, hub/route/configs.go, hub/route/proxies.go, hub/route/provider.go, hub/route/connections.go, hub/route/groups.go, hub/route/rules.go, hub/route/cache.go, hub/route/dns.go, hub/route/storage.go, hub/route/upgrade.go, hub/route/restart.go]
status: current
---

# Mihomo API Route Map

Use this page when answering questions about RESTful API routing, external controller behavior, authentication, or where to add an endpoint.

## Server Entrypoints

| Source | Meaning |
| --- | --- |
| `hub.ApplyConfig` | Calls `applyRoute` after executor applies runtime config |
| `hub.applyRoute` | Converts config controller fields into `route.Config` |
| `route.ReCreateServer` | Starts or restarts HTTP, HTTPS, Unix socket, and named pipe servers |
| `route.router` | Mounts all API routers and optional UI/DoH/debug routes |

## Controller Config Fields

| YAML / option | Runtime field | Effect |
| --- | --- | --- |
| `external-controller` / `-ext-ctl` | `route.Config.Addr` | HTTP API listen address |
| `external-controller-tls` | `route.Config.TLSAddr` | HTTPS API listen address |
| `external-controller-unix` / `-ext-ctl-unix` | `route.Config.UnixAddr` | Unix socket API |
| `external-controller-pipe` / `-ext-ctl-pipe` | `route.Config.PipeAddr` | Windows named pipe API |
| `secret` / `-secret` | `route.Config.Secret` | Bearer auth token |
| `external-ui` / `-ext-ui` | `route.SetUIPath` | Serves UI under `/ui` |
| `external-doh-server` | `route.Config.DohServer` | Mounts DoH handler if path starts with `/` |
| `external-controller-cors` | `route.Config.Cors` | CORS middleware options |

## Authentication

Source: `hub/route/server.go`.

If `secret` is non-empty, normal API routes use auth middleware. Requests should provide:

```text
Authorization: Bearer <secret>
```

For WebSocket requests, the middleware also accepts a `token` query parameter.

If `secret` is empty, the routes are not protected by this middleware.

## Top-Level Routes

Mounted in `route.router`:

| Method/path | Handler area | Source file |
| --- | --- | --- |
| `GET /` | hello/status | `hub/route/server.go` |
| `GET /logs` | log stream | `hub/route/server.go` |
| `GET /traffic` | traffic counters | `hub/route/server.go` |
| `GET /memory` | memory stats | `hub/route/server.go` |
| `GET /version` | version info | `hub/route/server.go` |
| `/configs` | config read/update/patch/geo | `hub/route/configs.go` |
| `/proxies` | proxy list, select, delay | `hub/route/proxies.go` |
| `/group` | group list and delay | `hub/route/groups.go` |
| `/rules` | rule list and disable in non-embed mode | `hub/route/rules.go` |
| `/connections` | connection list/close/WebSocket | `hub/route/connections.go` |
| `/providers/proxies` | proxy provider list/update/healthcheck | `hub/route/provider.go` |
| `/providers/rules` | rule provider list/update | `hub/route/provider.go` |
| `/cache` | fake-ip and DNS cache flushing | `hub/route/cache.go` |
| `/dns` | DNS query API | `hub/route/dns.go` |
| `/storage` | key-value storage API | `hub/route/storage.go` |
| `/restart` | restart API, disabled in embed mode | `hub/route/restart.go` |
| `/upgrade` | UI/core/geo update APIs | `hub/route/upgrade.go` |
| `/ui` and `/ui/*` | static external UI | `hub/route/server.go` |
| configured DoH path | DNS-over-HTTPS endpoint | `hub/route/doh.go` |
| `/debug` | profiler and GC endpoint in debug mode | `hub/route/server.go` |

## Nested Routes

### `/configs`

| Route | Meaning |
| --- | --- |
| `GET /configs` | Return current general config |
| `PUT /configs` | Replace config, disabled in embed mode |
| `PATCH /configs` | Patch selected runtime fields, disabled in embed mode |
| `POST /configs/geo` | Update geo databases, disabled in embed mode |

### `/proxies`

| Route | Meaning |
| --- | --- |
| `GET /proxies` | Return proxies plus provider proxies |
| `GET /proxies/{name}` | Return one proxy |
| `GET /proxies/{name}/delay` | Run URL delay test |
| `PUT /proxies/{name}` | Switch select-able proxy by JSON body `{ "name": "..." }` |
| `DELETE /proxies/{name}` | Clear forced selected child for non-selector select-able proxy |

### `/providers/proxies`

| Route | Meaning |
| --- | --- |
| `GET /providers/proxies` | List proxy providers |
| `GET /providers/proxies/{providerName}` | Return one provider |
| `PUT /providers/proxies/{providerName}` | Trigger provider update |
| `GET /providers/proxies/{providerName}/healthcheck` | Trigger provider health check |
| `GET /providers/proxies/{providerName}/{name}` | Return provider proxy |
| `GET /providers/proxies/{providerName}/{name}/healthcheck` | Run delay test for provider proxy |

### `/providers/rules`

| Route | Meaning |
| --- | --- |
| `GET /providers/rules` | List rule providers |
| `PUT /providers/rules/{name}` | Trigger rule provider update |

### Other Routers

| Route | Meaning |
| --- | --- |
| `GET /group` | List proxy groups |
| `GET /group/{name}` | Return one group |
| `GET /group/{name}/delay` | Group delay test |
| `GET /rules` | List rules |
| `PATCH /rules/disable` | Disable or enable selected rules, disabled in embed mode |
| `GET /connections` | List active connections or WebSocket stream depending headers |
| `DELETE /connections` | Close all connections |
| `DELETE /connections/{id}` | Close one connection |
| `POST /cache/fakeip/flush` | Flush fake-ip cache |
| `POST /cache/dns/flush` | Flush DNS cache |
| `GET /dns/query` | Query DNS |
| `GET /storage/{key}` | Read storage value |
| `PUT /storage/{key}` | Write storage value |
| `DELETE /storage/{key}` | Delete storage value |
| `POST /upgrade/ui` | Update external UI |
| `POST /upgrade` | Upgrade core, disabled in embed mode |
| `POST /upgrade/geo` | Update geo databases, disabled in embed mode |
| `POST /restart` | Restart process, disabled in embed mode |

## Adding An Endpoint

1. Pick the closest `hub/route/*.go` router.
2. Register the method and path in that router function.
3. Reuse existing context parser middleware where possible, such as `parseProxyName` or provider name parsers.
4. Read state through runtime packages such as `executor`, `tunnel`, provider maps, or cache modules.
5. For writes, consider auth, locks, embed mode restrictions, and runtime side effects.
6. Return structured JSON or `204 No Content` consistently with nearby handlers.

Cross-reference: [[development-recipes]].
