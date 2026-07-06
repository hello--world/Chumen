# TUN 和 macOS 原生网络技术的区别

这篇文档回答一个很容易混淆的问题：

```text
Mihomo 用的 TUN，和 macOS 原生的 VPN / NetworkExtension 技术，是一回事吗？
```

简短答案：

不是一回事，但解决的问题有重叠。

Mihomo 当前仓库里的 TUN 实现，主要是通过 `sing-tun` 创建或接管虚拟网卡，把进入虚拟网卡的 IP 包交给 Mihomo 的代理内核处理。macOS 原生方案一般指 Apple 的 NetworkExtension，尤其是 `NEPacketTunnelProvider`，它是 App Extension，由系统 VPN 配置、签名、权限和生命周期管理。

如果你要做命令行代理内核，Mihomo 现在的实现更直接。如果你要做“像系统 VPN 一样”的 macOS 原生 App，需要参考 Mihomo 的核心转发逻辑，但还要额外写 NetworkExtension 适配层。

## 先建立小白心智模型

你可以把两种方案理解成两种“接入系统网络流量”的方式。

### Mihomo TUN 模型

```text
系统路由表
  -> utunN 虚拟网卡
  -> sing-tun 读取 IP 包
  -> Mihomo listener handler
  -> tunnel 规则匹配
  -> outbound proxy / DIRECT
```

重点：

- Mihomo 自己负责创建或使用 TUN 设备。
- Mihomo 自己负责把 TUN 包接入代理内核。
- Mihomo 的配置文件控制 `tun.enable`、`tun.stack`、`tun.auto-route`、`tun.route-address` 等行为。
- macOS 上设备名通常是 `utun0`、`utun1` 这样的形式。

### macOS 原生 Packet Tunnel 模型

```text
系统 VPN 配置
  -> NetworkExtension 启动 Packet Tunnel Provider
  -> NEPacketTunnelProvider.packetFlow
  -> 你的 App Extension 读写 IP 包
  -> 自己的隧道协议或代理内核
```

重点：

- 这是 Apple 官方的 App Extension 模型。
- 需要 NetworkExtension entitlement、签名、配置文件和用户授权。
- 虚拟接口、路由、DNS、MTU 通过 `NEPacketTunnelNetworkSettings` 配置。
- IP 包不是直接从普通 Go 进程入口进来，而是通过 `packetFlow` 给 Provider。

## 关键区别总表

| 对比项 | Mihomo 当前 TUN | macOS 原生 Packet Tunnel |
| --- | --- | --- |
| 技术层级 | 代理内核内的虚拟网卡入口 | Apple NetworkExtension App Extension |
| 入口对象 | `listener/sing_tun` + `sing-tun` | `NEPacketTunnelProvider` |
| 包来源 | `tun.New` 创建或接管 TUN 设备 | 系统把匹配路由的 IP 包交给 `packetFlow` |
| macOS 设备名 | 代码规范到 `utunN` | 系统管理虚拟接口，不以项目配置为主 |
| 生命周期 | Mihomo 进程和配置热重载控制 | 系统 VPN 配置、Provider 启停控制 |
| 权限模型 | 通常需要本地提权或网络配置权限 | 需要 Apple entitlement、签名、用户授权 |
| 路由配置 | `auto-route`、`route-address`、`route-exclude-address` | `includedRoutes`、`excludedRoutes`、`includeAllNetworks`、`enforceRoutes` |
| DNS 行为 | `dns-hijack`，并把 TUN DNS 加入系统 DNS blacklist | 在 `NEPacketTunnelNetworkSettings` 里配置 DNS |
| 应用分流 | 项目有 UID、包名、接口等字段，但跨平台支持不同 | 可通过 per-app VPN、App Proxy 等原生机制做应用级策略 |
| 适合场景 | 命令行内核、跨平台核心、路由器、开发调试 | 原生 macOS App、系统设置里显示 VPN、企业/MDM、App Store 风格交付 |

## Mihomo 这边具体怎么实现

先看源码主链路：

```text
config/config.go
  -> parseTun
  -> hub/executor/executor.go
  -> updateTun
  -> listener/listener.go
  -> ReCreateTun
  -> listener/sing_tun/server.go
  -> sing_tun.New
  -> github.com/metacubex/sing-tun
```

这条链路说明：TUN 不是一个单独的系统 App Extension，它是 Mihomo 配置应用过程中的一个 listener。

### 配置入口

TUN 配置结构在 `config/config.go` 的 `RawTun`：

```text
RawTun
  enable
  device
  stack
  dns-hijack
  auto-route
  auto-detect-interface
  mtu
  route-address
  route-exclude-address
  file-descriptor
  recvmsgx / sendmsgx
  ...
```

默认值也在 `DefaultRawConfig` 里：

```text
tun.enable = false
tun.stack = gVisor
tun.dns-hijack = 0.0.0.0:53
tun.auto-route = true
tun.auto-detect-interface = true
```

小白要注意：默认 `enable` 是 `false`，所以项目默认不会打开 TUN。只有配置里启用后，才会走虚拟网卡路径。

### 栈类型

栈类型定义在 `constant/tun.go`：

```text
gVisor
System
Mixed
```

配置里通常写小写：

```yaml
tun:
  enable: true
  stack: system
```

含义可以先粗略理解为：

- `gvisor`：使用用户态网络栈处理更多协议细节。
- `system`：更多依赖系统网络栈能力。
- `mixed`：混合模式。

具体差异在 `sing-tun` 依赖里实现，本仓库主要把配置转交给 `tun.NewStack(...)`。

### 配置如何变成运行时 TUN

`parseTun` 会把 YAML 转成运行时 `LC.Tun`：

```text
RawTun
  -> parseTun
  -> general.Tun
```

这里还有一个细节：IPv4 TUN 地址默认来自 DNS fake-ip 段，如果 fake-ip 无效，则回退到 `198.18.0.1/16`，再取 `/30` 前缀。

之后 `executor.ApplyConfig` 会调用 `updateTun`，再进入：

```text
listener.ReCreateTun(general.Tun, tunnel.Tunnel)
```

`ReCreateTun` 会比较新旧配置：

- 配置没变：调用 `tunLister.OnReload()`，避免重复创建。
- 配置变了：关闭旧 TUN，再创建新 TUN。
- `tun.enable = false`：关闭后直接返回。
- `tun.enable = true`：调用 `sing_tun.New(...)`。

### macOS 上为什么是 utunN

`listener/sing_tun/server.go` 里有一个关键逻辑：

```text
runtime.GOOS == "darwin" 时，基础名称使用 utun
```

如果用户配置的设备名不符合 macOS 规则，代码会重新生成：

```text
utun0
utun1
utun2
...
```

`checkTunName` 在 Darwin 上要求：

- 名字必须以 `utun` 开头。
- 后面必须是数字。

这说明 Mihomo 在 macOS 上不是随便创建一个叫 `Meta` 的网卡，而是适配了 macOS 的 utun 命名习惯。

### file-descriptor 是什么

`RawTun` 和运行时 TUN 都有：

```text
file-descriptor
```

在 `listener/sing_tun/server.go` 中，如果 `FileDescriptor > 0`，代码会尝试从这个 fd 取真实的 TUN 名称。

Darwin 版本在 `listener/sing_tun/tun_name_darwin.go`：

```text
GetsockoptString(fd, SYSPROTO_CONTROL, UTUN_OPT_IFNAME)
```

这说明一个重要能力：

如果外部原生层已经创建或拿到了一个 utun fd，Mihomo 有路径接收这个 fd，而不是一定自己创建 TUN。

但注意：这不等于仓库已经实现了 `NEPacketTunnelProvider`。它只是说明底层有“接管外部 TUN fd”的入口。

### sing-tun 在这里做什么

`listener/sing_tun/server.go` 会把配置组装成 `tun.Options`：

```text
Name
MTU
GSO
Inet4Address
Inet6Address
AutoRoute
StrictRoute
RouteAddress
RouteExcludeAddress
IncludeInterface
ExcludeInterface
FileDescriptor
EXP_RecvMsgX
EXP_SendMsgX
...
```

然后调用：

```text
tunNew(tunOptions)
tun.NewStack(stack, stackOptions)
tunStack.Start()
```

所以本仓库自己的职责主要是：

1. 解析配置。
2. 选择设备名和路由参数。
3. 创建 Mihomo listener handler。
4. 把 handler、TUN 设备和 stack options 接起来。
5. 生命周期管理和配置热重载。

真正跨平台 TUN 设备细节在 `github.com/metacubex/sing-tun` 里。

## macOS 原生 NetworkExtension 是什么

macOS 原生网络扩展不是一个单点技术，而是一组系统扩展点。

### Packet Tunnel Provider

这是和 TUN 最接近的原生技术。

Apple 官方文档说明，`NEPacketTunnelProvider` 是 packet tunnel provider app extension 的主类。它通过 `packetFlow` 访问虚拟网络接口。Provider 使用 `setTunnelNetworkSettings` 设置虚拟 IP、DNS、HTTP 代理、进入隧道的目的网络、排除的目的网络和 MTU。

小白理解：

```text
Packet Tunnel Provider = 系统认可的“虚拟网卡 VPN 插件”
```

它和 Mihomo TUN 的共同点：

- 都能处理 IP 包。
- 都可以做全局流量接管。
- 都需要配置路由、DNS、MTU。

不同点：

- Packet Tunnel Provider 必须运行在 App Extension 生命周期里。
- 它需要 entitlement 和签名。
- 它通过 `packetFlow` 读写包，不是直接等同于普通进程里的 `tun.New(...)`。

### NETunnelProviderManager

这是包含 App 用来创建、保存、启停 VPN 配置的管理对象。

小白理解：

```text
NETunnelProviderManager = 系统设置里那条 VPN 配置的管理器
```

如果你做 macOS 原生 App，通常是：

```text
主 App
  -> NETunnelProviderManager 保存 VPN 配置
  -> 用户授权
  -> 系统启动 Packet Tunnel Provider 扩展
```

这和 Mihomo 的配置热重载不同。Mihomo 是自己读 YAML、自己应用配置；NetworkExtension 是系统保存 VPN 配置，系统启动扩展。

### NEPacketTunnelNetworkSettings

这是 Packet Tunnel Provider 给系统的虚拟接口设置。

它对应 Mihomo 里的这些概念：

| Mihomo TUN | NetworkExtension |
| --- | --- |
| `inet4-address` / fake-ip 派生地址 | IPv4 settings |
| `inet6-address` | IPv6 settings |
| `route-address` | included routes |
| `route-exclude-address` | excluded routes |
| `dns-hijack` / DNS 服务 | DNS settings |
| `mtu` | MTU |

但对应关系不是一行代码替换，因为 Mihomo 的路由由 `sing-tun` 和项目配置驱动，NetworkExtension 的路由由系统 VPN 配置驱动。

### App Proxy Provider

Apple 的 SimpleTunnel 示例说明，App Proxy Provider 处理的是应用网络数据流，支持 TCP/UDP flow。

这和 TUN 不同：

- TUN / Packet Tunnel 是 IP 包层。
- App Proxy 是应用 flow 层。

如果你只想代理某些受管 App 的 TCP/UDP flow，App Proxy 可能合适。如果你要像 TUN 一样接管系统路由和 IP 包，Packet Tunnel 更接近。

### Filter Provider

Filter Provider 更像网络内容过滤器，用于检查、放行或阻止流量。

它不是代理内核的直接替代品：

- 它主要负责过滤决策。
- 不适合直接拿来实现 Mihomo 这种完整代理转发核心。

### 系统代理设置

macOS 还有 HTTP/SOCKS 系统代理设置。

这和 TUN/Packet Tunnel 差别更大：

- 系统代理主要作用在支持系统代理的应用。
- 它不是 IP 层虚拟网卡。
- 不能天然接管所有不走系统代理的流量。

Mihomo 的 `mixed-port`、`socks-port`、`port` 更接近系统代理场景；Mihomo 的 `tun` 才是虚拟网卡场景。

## 能不能参考 Mihomo 的实现

可以参考，但要分清参考哪一层。

### 可以直接参考的部分

这些部分很适合作为实现参考：

| 目标 | 可参考源码 |
| --- | --- |
| YAML TUN 配置设计 | `config/config.go` 的 `RawTun` 和 `parseTun` |
| 配置热重载 | `listener/listener.go` 的 `ReCreateTun` |
| macOS utun 命名 | `listener/sing_tun/server.go` 的 `CalculateInterfaceName` 和 `checkTunName` |
| 外部 fd 接入 | `listener/sing_tun/server.go` 的 `FileDescriptor` 分支 |
| Darwin fd 取接口名 | `listener/sing_tun/tun_name_darwin.go` |
| DNS hijack 接入 | `listener/sing_tun/server.go` 的 `DNSHijack` 解析 |
| Mihomo 流量接入 | `sing.NewListenerHandler(... Type: C.TUN ...)` |
| TUN stack 启动 | `tun.NewStack(...)` |

如果你要学习“一个代理内核怎样接 TUN”，这些就是最有价值的源码入口。

### 不应该直接照抄的部分

如果你的目标是 macOS 原生 VPN App，不应该只把 `sing_tun.New` 塞进 App Extension 然后认为完成了。

原因：

1. NetworkExtension 有自己的生命周期。
2. Provider 在 App Extension 沙盒里运行。
3. Apple 要求 entitlement 和签名。
4. Packet Tunnel 的包入口是 `packetFlow`。
5. 系统 VPN 配置由 `NETunnelProviderManager` 管理，不是直接读 Mihomo YAML。

更合理的路线是：

```text
主 App
  -> 管理配置和用户界面
  -> 保存 NETunnelProviderManager
  -> 启动 Packet Tunnel Provider

Packet Tunnel Provider
  -> setTunnelNetworkSettings
  -> 从 packetFlow 读 IP 包
  -> 桥接到 Mihomo core 或 sing-tun 兼容层
  -> 把返回包写回 packetFlow

Mihomo core
  -> 继续负责规则、DNS、代理组、outbound、日志
```

### file-descriptor 路线是否可行

本仓库支持 `tun.file-descriptor`，说明作者考虑过外部 TUN fd 接入。

但是，对 macOS 原生 NetworkExtension 来说，要谨慎：

- `NEPacketTunnelProvider.packetFlow` 是 Apple 提供的对象 API。
- 它不一定等价于一个你能直接交给 Go 的 utun fd。
- 如果拿不到可传递 fd，就需要写 `packetFlow` 到 Go core 的桥接层。

所以文档结论是：

```text
Mihomo 的 file-descriptor 支持可以作为“外部原生层接入 TUN”的参考点；
但做 NetworkExtension 时，是否能直接传 fd，要以 Apple API 和实际工程验证为准。
```

## 推荐实现路线

### 路线 A：继续使用 Mihomo 当前 TUN

适合：

- 命令行工具。
- 本地开发调试。
- 路由器或服务端环境。
- 不追求系统设置里显示原生 VPN。

实现重点：

1. 用 YAML 打开 `tun.enable`。
2. 配置 `stack`。
3. 配置 `auto-route`、`route-address`、`route-exclude-address`。
4. 确认权限足够创建 TUN 和改路由。
5. 用日志检查 `[TUN] Tun adapter listening at`。

优点：

- 和当前仓库最贴合。
- 跨平台逻辑集中。
- 改动少。

缺点：

- macOS 原生 App 集成不够系统化。
- 权限和路由修改可能带来用户体验问题。
- 不天然拥有 NetworkExtension 的系统 VPN 生命周期。

### 路线 B：做 macOS 原生 Packet Tunnel App

适合：

- 要做完整 macOS 桌面 App。
- 要在系统 VPN 设置中管理。
- 要走 Apple 官方网络扩展模型。
- 要更好适配企业管理或 per-app 策略。

实现重点：

1. 创建主 App。
2. 创建 Packet Tunnel Provider extension。
3. 申请并配置 NetworkExtension entitlement。
4. 主 App 用 `NETunnelProviderManager` 保存 VPN 配置。
5. Provider 在 `startTunnel` 里设置 `NEPacketTunnelNetworkSettings`。
6. Provider 处理 `packetFlow`。
7. 把包交给 Mihomo core 或一个适配层。
8. 保留 Mihomo 的规则、代理、DNS 和日志能力。

优点：

- macOS 原生体验更好。
- 生命周期由系统管理。
- 更适合正式 App。

缺点：

- 工程复杂度明显更高。
- 需要 Apple entitlement 和签名。
- 不能假设普通 Go 进程里的 TUN 代码可以原样搬进去。

### 路线 C：系统代理或 App Proxy

适合：

- 只代理 HTTP/SOCKS。
- 只需要应用层 flow。
- 不需要全局 IP 包接管。

实现重点：

- 用 Mihomo 的 `mixed-port` / `socks-port` / `port` 提供代理端口。
- macOS App 设置系统代理，或使用 App Proxy Provider。

优点：

- 比 Packet Tunnel 简单。
- 不一定需要处理完整 IP 包。

缺点：

- 覆盖范围不如 TUN。
- 不走系统代理的 App 可能不会被接管。

## 和源码对应的实现草图

如果你要做一个“macOS 原生壳 + Mihomo core”，可以按这个边界切分：

```text
Swift / macOS App 层
  - UI
  - 配置存储
  - VPN 开关
  - NETunnelProviderManager

Swift Packet Tunnel Provider 层
  - startTunnel
  - stopTunnel
  - setTunnelNetworkSettings
  - packetFlow read/write
  - 和 Go core 通信

Go / Mihomo core 层
  - config.Parse
  - tunnel.HandleTCPConn / HandleUDPPacket
  - rules
  - adapter outbound
  - dns service
```

如果走 `file-descriptor` 方向，重点看：

```text
config/config.go
listener/config/tun.go
listener/inbound/tun.go
listener/sing_tun/server.go
listener/sing_tun/tun_name_darwin.go
```

如果走 `packetFlow` 桥接方向，重点不是 `file-descriptor`，而是要写一个适配层：

```text
packetFlow 读到 IP 包
  -> 解析 TCP/UDP/ICMP
  -> 转成 Mihomo 能处理的连接或 packet abstraction
  -> 走 tunnel/rules/adapter
  -> 把响应包封回 packetFlow
```

这个适配层不是当前仓库已经完整提供的东西。

## 常见误解

### 误解 1：TUN 就等于 macOS 原生 VPN

不对。

TUN 是一种虚拟网卡/包入口思路。macOS 原生 VPN 是 NetworkExtension 体系，包含权限、签名、系统配置和扩展生命周期。

### 误解 2：有 utun 就等于用了 NetworkExtension

不对。

macOS 上很多虚拟网络路径都会表现为 `utunN`，但是否使用 NetworkExtension，要看有没有 `NEPacketTunnelProvider`、extension target、entitlement 和系统 VPN 配置。

当前运行时代码和 Go 源码中没有 `NEPacketTunnelProvider`、`NETunnelProviderManager`、`packetFlow` 的实现，所以仓库本身没有实现 Apple 原生 Packet Tunnel Provider。

### 误解 3：Packet Tunnel 可以无成本复用 Mihomo TUN

不对。

Mihomo 的 TUN listener 可以参考，但 Packet Tunnel Provider 的包入口、生命周期、沙盒和配置管理都不同。需要适配层。

### 误解 4：系统代理、App Proxy、TUN 是一回事

不对。

系统代理和 App Proxy 更偏应用层 flow；TUN 和 Packet Tunnel 更偏 IP 包层。

## 学习时应该先读哪些文件

按这个顺序：

1. `docs/config.yaml` 的 `tun:` 示例。
2. `config/config.go` 的 `RawTun`。
3. `config/config.go` 的 `DefaultRawConfig`。
4. `config/config.go` 的 `parseTun`。
5. `listener/listener.go` 的 `ReCreateTun`。
6. `listener/sing_tun/server.go` 的 `New`。
7. `listener/sing_tun/tun_name_darwin.go`。
8. `constant/tun.go`。
9. `go.mod` 里的 `github.com/metacubex/sing-tun` 依赖。

不要一开始就读 `sing-tun` 依赖内部。先把本仓库如何接入它看懂。

## 读完后你应该能回答

1. Mihomo 的 TUN 是从哪个配置字段打开的？
2. `tun.stack` 有哪几种值？
3. macOS 上为什么会出现 `utunN`？
4. `file-descriptor` 在源码里有什么作用？
5. `NEPacketTunnelProvider` 和 Mihomo TUN listener 最大的区别是什么？
6. 如果要做 macOS 原生 App，为什么需要额外适配层？
7. 什么场景应该选当前 TUN，什么场景应该选 NetworkExtension？

## 官方参考链接

- Apple `NEPacketTunnelProvider`: <https://developer.apple.com/documentation/networkextension/nepackettunnelprovider>
- Apple `NEPacketTunnelNetworkSettings`: <https://developer.apple.com/documentation/networkextension/nepackettunnelnetworksettings>
- Apple `NETunnelProviderManager`: <https://developer.apple.com/documentation/networkextension/netunnelprovidermanager>
- Apple VPN routing guide: <https://developer.apple.com/documentation/networkextension/routing-your-vpn-network-traffic>
- Apple SimpleTunnel sample: <https://github.com/ios-sample-code/SimpleTunnel>

## 本仓库结论

本项目的 TUN 实现值得参考，尤其适合学习：

- 代理内核如何接虚拟网卡。
- 配置如何控制路由、DNS、stack 和设备名。
- macOS 上如何处理 `utunN`。
- 如何给外部 TUN fd 留入口。

但如果目标是 macOS 原生 VPN App，不能只参考 `listener/sing_tun`。你还需要参考 Apple 的 NetworkExtension 模型，写主 App、Provider extension、VPN 配置管理和 `packetFlow` 适配层。
