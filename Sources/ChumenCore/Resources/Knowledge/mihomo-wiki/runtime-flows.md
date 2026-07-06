---
title: Mihomo Runtime Flows
category: architecture
tags: [runtime, startup, tcp, udp, tunnel, lifecycle]
source_files: [main.go, hub/hub.go, hub/executor/executor.go, tunnel/tunnel.go, tunnel/connection.go]
status: current
---

# Mihomo Runtime Flows

## Startup Flow

```text
main
  -> register flags
  -> configure net.DefaultResolver guard
  -> handle special subcommands
  -> handle -v
  -> resolve homeDir and configFile
  -> config.Init
  -> if -t then parse and exit
  -> hub.Parse
  -> updater.RegisterGeoUpdater if enabled
  -> post-up if configured
  -> wait for SIGINT/SIGTERM/SIGHUP
```

## Config Application Flow

```text
hub.Parse
  -> executor.Parse / executor.ParseWithBytes
  -> config.Parse
  -> apply CLI override options
  -> hub.ApplyConfig
    -> applyRoute
    -> executor.ApplyConfig
```

## executor.ApplyConfig Order

```text
log.SetLevel
tunnel.OnSuspend
ca.ResetCertificate
updateExperimental
updateUsers
updateProxies
updateRules
updateSniffer
updateHosts
updateGeneral
updateNTP
updateDNS
updateListeners
updateTun
updateIPTables
updateTunnels
tunnel.OnInnerLoading
initInnerTcp
loadProvider(proxy providers)
updateProfile
loadProvider(rule providers)
runtime.GC
tunnel.OnRunning
updateUpdater
resolver.ResetConnection
```

## Tunnel Status

| Status | Meaning |
| --- | --- |
| `suspend` | Normal traffic is not handled |
| `inner` | Only inner traffic is handled |
| `running` | Normal traffic is handled |

Source: `tunnel/status.go`, `tunnel.isHandle`.

## TCP Flow

```text
listener
  -> tunnel.HandleTCPConn
  -> icontext.NewConnContext
  -> handleTCPConn
  -> status check
  -> metadata.Valid
  -> fixMetadata
  -> preHandleMetadata
  -> optional TCPSniff
  -> resolveMetadata
  -> retry(proxy.DialContext)
  -> logMetadata
  -> statistic.NewTCPTracker
  -> handleSocket
  -> common/net.Relay
```

## UDP Flow

```text
listener
  -> tunnel.HandleUDPPacket
  -> initUDP once
  -> hash packet key to UDP worker queue
  -> processUDP
  -> handleUDPConn
  -> status check
  -> metadata.Valid
  -> fixMetadata
  -> preHandleMetadata clone precheck
  -> natTable.GetOrCreate packetSender
  -> resolveMetadata
  -> proxy.ListenPacketContext
  -> statistic.NewUDPTracker
  -> handleUDPToLocal goroutine
  -> sender.Process
  -> sender.Send(packet)
```

## resolveMetadata Behavior

```text
if metadata.SpecialProxy != "":
  find named proxy and return

handle hosts
create RuleMatchHelper
respect find-process-mode

switch mode:
  Direct -> proxies["DIRECT"]
  Global -> proxies["GLOBAL"]
  Rule -> match(metadata, helper)
```

## match Behavior

```text
for rule in getRules(metadata):
  matched, adapterName := rule.Match(metadata, helper)
  if matched:
    adapter := proxies[adapterName]
    if missing: continue
    if proxy chain contains PASS: continue
    if UDP and adapter.SupportUDP false: continue
    return adapter, rule

return proxies["DIRECT"], nil
```

## Metadata Preprocessing

`preHandleMetadata` handles:

- DNS mapping from IP back to host.
- fake-ip restoration.
- hosts mapping.
- fake DNS record missing errors.

`fixMetadata` handles:

- IP unmap.
- Host string that is actually IP.

## Retry Behavior

`retry` tries up to 10 times and stops early for:

- `resolver.ErrIPNotFound`
- `resolver.ErrIPVersion`
- `resolver.ErrIPv6Disabled`
- `loopback.ErrReject`

## Answering Tip

If asked "why did traffic choose X?", inspect:

1. `mode`
2. `Metadata`
3. rules order
4. proxy existence
5. UDP support
6. logs from `logMetadata`
