# 06. 调试、排障和常见问题

这一章给你一个排查顺序。不要看到问题就钻协议细节，先判断问题在哪一层。

## 1. 总体排查顺序

建议顺序：

```text
配置是否能解析
  -> 端口是否监听
  -> 请求是否进入 listener
  -> Metadata 是否正确
  -> 规则是否命中
  -> 代理是否存在和可用
  -> DNS 是否正确
  -> 出站协议是否连通
```

## 2. 配置无法启动

先跑：

```sh
bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-debug -t -f your-config.yaml
```

常见错误：

| 错误关键词 | 可能原因 |
| --- | --- |
| `proxy ... not found` | rules 或 group 引用了不存在的代理 |
| `rule set ... not found` | RULE-SET 引用了不存在的 rule-provider |
| `format invalid` | rule 格式错误 |
| `duplicate name` | proxy、group、listener 名称重复 |
| `path is not subpath` | 路径不在 home dir 或 SAFE_PATHS |
| `unsupported type` | type 写错或不支持 |

## 3. 端口没有监听

检查配置：

```yaml
mixed-port: 10801
allow-lan: false
```

理解实际监听：

| allow-lan | bind-address | 结果 |
| --- | --- | --- |
| false | 任意 | `127.0.0.1:<port>` |
| true | `*` | `:<port>` |
| true | `192.168.1.2` | `192.168.1.2:<port>` |

源码位置：

```text
listener/listener.go -> genAddr
listener/listener.go -> ReCreateMixed / ReCreateHTTP / ReCreateSocks
```

## 4. 规则不生效

先检查模式：

```yaml
mode: rule
```

如果是：

```yaml
mode: direct
```

规则不会决定最终代理。

再检查规则顺序：

```yaml
rules:
  - MATCH,DIRECT
  - DOMAIN-SUFFIX,example.com,PROXY
```

这就是错的，因为 `MATCH` 放在前面会先兜底。

正确：

```yaml
rules:
  - DOMAIN-SUFFIX,example.com,PROXY
  - MATCH,DIRECT
```

源码位置：

```text
config.parseRules
rules.ParseRule
tunnel.match
```

## 5. UDP 不通

检查：

1. 规则命中的代理是否支持 UDP。
2. 入站是否开启 UDP。
3. 出站协议本身是否支持 UDP。
4. 日志里有没有 `UDP is not supported`。

源码位置：

```text
tunnel.handleUDPConn
tunnel.match
constant.ProxyAdapter.SupportUDP
```

`tunnel.match` 里如果发现 UDP 但代理不支持 UDP，会跳过这个代理继续匹配下一条规则。

## 6. DNS 问题

如果启用 DNS：

```yaml
dns:
  enable: true
  listen: 127.0.0.1:1053
```

启动日志应有：

```text
DNS server(UDP) listening at
DNS server(TCP) listening at
```

如果 fake-ip 相关出错，重点看：

```text
tunnel.preHandleMetadata
component/fakeip
component/resolver
```

## 7. provider 下载失败

检查：

- `type` 是 file、http 还是 inline。
- http URL 是否可访问。
- 是否需要 `proxy` 来下载。
- `path` 是否在安全路径内。
- `filter` 是否把节点都过滤掉。
- `size-limit` 是否太小。
- rule provider 的 `behavior` 和 `format` 是否正确。

源码位置：

```text
adapter/provider/parser.go
rules/provider/parse.go
component/resource/vehicle.go
component/resource/fetcher.go
```

## 8. API 无法访问

配置：

```yaml
external-controller: 127.0.0.1:9090
secret: test
```

请求：

```sh
curl -H 'Authorization: Bearer test' http://127.0.0.1:9090/version
```

如果没设 secret，就不需要 Authorization。

源码位置：

```text
hub/route/server.go
hub/route/configs.go
hub/route/proxies.go
```

如果你要系统查 API endpoint，不要只在一个文件里找。API 路由分散在 `hub/route/*.go`，AI 知识库里的专门地图是：

```text
omx_wiki/api-route-map.md
```

## 9. 安全路径错误

错误：

```text
path is not subpath of home directory or SAFE_PATHS
```

解决方式：

1. 把文件放到 `-d` 指定目录下。
2. 使用相对路径，让它基于 home dir。
3. 设置 `SAFE_PATHS`。

示例：

```sh
SAFE_PATHS=/opt/mihomo-assets bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-learning -f config.yaml
```

源码位置：

```text
constant/path.go
```

## 10. 常见问答

### Q1: 为什么我改了配置，规则还是不生效？

优先检查：

- `mode` 是否是 `rule`。
- 规则顺序是否正确。
- target 名称是否存在。
- 域名是否被 DNS/fake-ip/sniffer 正确还原。

### Q2: 为什么 docs/config.yaml 不能直接测试通过？

它是完整参考模板，包含占位路径和示例字段。学习阶段用：

```text
docs/learning-minimal.yaml
```

### Q3: 为什么我不应该先读 transport？

`transport/` 是协议细节。你还不知道请求如何进入、规则如何选择、代理如何调用时，直接看协议会缺少上下文。

### Q4: 为什么要区分 listener 和 adapter？

因为它们方向相反：

- listener 接收本地流量。
- adapter 发起远端连接。

中间由 tunnel 和 rules 连接。

### Q5: 修改代码后至少跑什么？

只改文档：

```sh
bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-learning -t -f docs/learning-minimal.yaml
```

改 Go 代码：

```sh
go test ./...
```

如果是协议集成：

```sh
cd test
make test
```
