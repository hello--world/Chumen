# 03. 配置如何进入运行态

这一章讲清楚 YAML 配置如何一步步变成 Go 运行对象。

## 1. 配置不是直接生效的

很多新手会以为：

```yaml
mixed-port: 10801
```

程序就直接监听了 `10801`。

实际上中间有很多层：

```text
YAML 文件
  -> RawConfig
  -> Config
  -> executor.ApplyConfig
  -> listener.ReCreateMixed
  -> mixed.New
```

理解这条链路，是读懂项目的关键。

## 2. RawConfig 和 Config

`config/config.go` 里有两类结构体。

### RawConfig

`RawConfig` 直接对应 YAML 字段。

例如 YAML：

```yaml
mixed-port: 10801
allow-lan: false
mode: rule
```

会进入 `RawConfig` 的对应字段。

### Config

`Config` 是运行时配置。

它不只是简单字符串和数字，里面会包含已经解析好的对象：

- `Proxies map[string]C.Proxy`
- `Rules []C.Rule`
- `Providers map[string]P.ProxyProvider`
- `Hosts *trie.DomainTrie[...]`
- `DNS *DNS`
- `Listeners map[string]C.InboundListener`

所以：

```text
RawConfig 是原材料
Config 是半成品或成品
executor.ApplyConfig 把成品装到机器上
```

## 3. Parse 调用链

```text
config.Parse(buf)
  -> UnmarshalRawConfig(buf)
    -> DefaultRawConfig()
    -> age.DecryptBytes(buf)
    -> yaml.Unmarshal(buf, rawCfg)
  -> ParseRawConfig(rawCfg)
```

### DefaultRawConfig

它先创建一份有默认值的 RawConfig，再把用户 YAML 覆盖上去。

所以配置文件里没写的字段，不一定是零值，而可能来自默认值。

例如：

| 字段 | 默认值 |
| --- | --- |
| `allow-lan` | false |
| `bind-address` | `*` |
| `mode` | rule |
| `ipv6` | true |
| `log-level` | info |
| `dns.enable` | false |
| `tun.enable` | false |
| `profile.store-selected` | true |

## 4. ParseRawConfig 的顺序

核心顺序：

```text
parseGeneral
temporaryUpdateGeneral
parseController
parseExperimental
parseIPTables
parseNTP
parseProfile
parseTLS
parseProxies
parseListeners
parseRuleProviders
parseSubRules
parseRules
parseHosts
parseIPV6
parseDNS
parseTun
parseTuicServer
parseAuthentication
verify tunnels
parseSniffer
```

为什么顺序重要：

- `rules` 需要知道目标代理是否存在，所以要先 `parseProxies`。
- `rule-providers` 可能被 rules 引用，所以要先解析。
- `dns` 和 `tun` 都依赖 IPv6 总开关。
- geodata 相关配置会影响规则解析，所以要临时应用 general。

## 5. 一个字段的完整流向：mixed-port

配置：

```yaml
mixed-port: 10801
```

源码流向：

```text
RawConfig.MixedPort
  -> parseGeneral
  -> General.Inbound.MixedPort
  -> Config.General
  -> executor.ApplyConfig
  -> updateListeners
  -> listener.ReCreateMixed(general.MixedPort, tunnel.Tunnel)
  -> genAddr(bindAddress, port, allowLan)
  -> mixed.New(addr, tunnel)
  -> socks.NewUDP(addr, tunnel)
```

关键点：

- TCP mixed listener 和 UDP socks listener 都会创建。
- 如果端口为 0，不会监听。
- 如果地址没变，热更新时会复用旧 listener。

## 6. mode 的流向

配置：

```yaml
mode: rule
```

源码流向：

```text
RawConfig.Mode
  -> parseGeneral
  -> Config.General.Mode
  -> executor.updateGeneral
  -> tunnel.SetMode
```

支持模式在 `tunnel/mode.go`：

| mode | 含义 |
| --- | --- |
| `direct` | 所有流量直连 |
| `global` | 所有流量走 GLOBAL |
| `rule` | 按规则匹配 |

## 7. proxies 的流向

配置示例：

```yaml
proxies:
  - name: node-a
    type: ss
    server: example.com
    port: 443
    cipher: 2022-blake3-aes-128-gcm
    password: password
```

源码流向：

```text
RawConfig.Proxy
  -> parseProxies
  -> adapter.ParseProxy
  -> switch type
  -> outbound.NewShadowSocks
  -> outbound.NewAutoCloseProxyAdapter
  -> adapter.NewProxy
  -> Config.Proxies["node-a"]
  -> executor.updateProxies
  -> tunnel.UpdateProxies
```

`adapter.ParseProxy` 是出站代理配置的工厂函数。

## 8. proxy-groups 的流向

配置示例：

```yaml
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - node-a
      - DIRECT
```

源码流向：

```text
RawConfig.ProxyGroup
  -> parseProxies
  -> proxyGroupsDagSort
  -> outboundgroup.ParseProxyGroup
  -> NewSelector
  -> adapter.NewProxy(group)
  -> Config.Proxies["PROXY"]
```

为什么代理组也放到 `Config.Proxies`：

因为规则只关心目标名字，不关心它是具体代理还是代理组。

## 9. rules 的流向

配置：

```yaml
rules:
  - DOMAIN-SUFFIX,example.org,PROXY
  - MATCH,DIRECT
```

源码流向：

```text
RawConfig.Rule
  -> parseRules
  -> rules/common.ParseRulePayload
  -> rules.ParseRule
  -> rules/wrapper.NewRuleWrapper
  -> Config.Rules
  -> executor.updateRules
  -> tunnel.UpdateRules
```

`parseRules` 会校验：

- 规则格式是否正确。
- target 代理或子规则是否存在。
- RULE-SET 引用的 rule provider 是否存在。

## 10. dns 的流向

配置：

```yaml
dns:
  enable: true
  listen: 127.0.0.1:1053
```

源码流向：

```text
RawConfig.DNS
  -> parseDNS
  -> Config.DNS
  -> executor.updateDNS
  -> dns.NewResolver
  -> dns.NewEnhancer
  -> dns.NewService
  -> dns.ReCreateServer
```

如果 `dns.enable=false`，`updateDNS` 会清空默认 resolver 并关闭 DNS server。

## 11. listeners 数组的流向

配置：

```yaml
listeners:
  - name: local-socks
    type: socks
    port: 7891
```

源码流向：

```text
RawConfig.Listeners
  -> parseListeners
  -> listener.ParseListener
  -> IN.NewSocks
  -> Config.Listeners
  -> executor.updateListeners
  -> listener.PatchInboundListeners
  -> inboundListener.Listen(tunnel)
```

注意：

- 顶层 `mixed-port` 走 `ReCreateMixed`。
- `listeners:` 数组走 `PatchInboundListeners`。

这是两套入口配置路径。

## 12. provider 的流向

proxy provider：

```text
proxy-providers
  -> adapter/provider.ParseProxyProvider
  -> file/http/inline
  -> NewProxySetProvider 或 NewInlineProvider
  -> executor.loadProvider
  -> provider.Initial
```

rule provider：

```text
rule-providers
  -> rules/provider.ParseRuleProvider
  -> file/http/inline
  -> NewRuleSetProvider 或 NewInlineProvider
  -> executor.loadProvider
  -> provider.Initial
```

provider 可能读取本地文件，也可能远程下载。

远程下载后的缓存路径通常由：

```text
C.Path.GetPathByHash(prefix, url)
```

生成。

## 13. 配置调试方法

只测试配置：

```sh
bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-learning -t -f your-config.yaml
```

如果报错：

1. 先看错误里有没有 `rules[数字]`。
2. 有就去看对应规则。
3. 如果是 `proxy not found`，检查 proxies/proxy-groups 名称。
4. 如果是 `path is not subpath`，检查 `-d`、相对路径和 `SAFE_PATHS`。
5. 如果是 provider 错误，检查 URL、path、type、format、behavior。

## 14. 本章练习

练习 1：找出 `mixed-port` 在源码中的完整路径。

练习 2：找出 `MATCH,DIRECT` 是在哪个函数里变成规则对象的。

练习 3：在 `docs/learning-minimal.yaml` 增加：

```yaml
external-controller: 127.0.0.1:9090
secret: test
```

然后运行配置测试，观察是否通过。
