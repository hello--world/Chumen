# Chumen 安全模型

本文档是 Chumen 本地保护模型的权威说明。修改安全、PIN、应用锁屏、Keychain、运行明文、日志或 AI 审核边界时，必须同步更新 [English](security-model.en.md)。

## 文档语言规则

- 项目文档必须同时提供中文和英文。
- 新增或修改安全、设计、首次启动、AI、配置持久化相关文档时，必须同步更新两个语言版本。
- 中文面向主要使用者，优先说明产品语义和操作后果。
- 英文面向后续代码审查、外部贡献者和 AI 阅读，必须保留同样的约束和边界。

## 目标

- 让代理订阅、节点、生成的运行配置、controller secret 和本地设置避免以普通明文文件存在。
- 防止普通扫描、误分享、简单备份泄漏，以及“熟人随手打开看看”暴露代理信息。
- 保持默认体验像正常软件：除非用户显式开启应用锁屏，否则 Chumen 重新打开时不要求输入 PIN。
- 统一使用 mihomo 内置 age 能力作为配置加密模型，不再维护 Chumen 自己的一套长期配置加密格式。
- 所有影响安全和运行状态的通知，都必须同步写入日志，方便排查。

## 非目标

- 这不是 root/admin 级安全边界。
- 这不能防止已经以同一 macOS 用户身份运行的恶意程序。
- 这不是高强度密码管理器设计。
- Keychain 只是 age 私钥的可选存储位置，不是 Chumen 配置保护模型的默认信任锚点。

## 核心语义

PIN 在 Chumen 中有两个互相独立的用途：

1. PIN 可以参与保护解密本地配置所需的 age 私钥。
2. PIN 可以可选地作为应用启动锁屏凭据。

默认行为：

- 配置文件默认加密保存。
- 首次启动默认启用 PIN 保护 age 私钥。
- 应用锁屏默认关闭。
- 当应用锁屏关闭时，Chumen 可以用本地应用管理的包装密钥自动解锁 PIN 保护的 age 私钥，让软件像普通工具一样打开。
- 当应用锁屏开启时，必须删除自动解锁包装密钥，启动时要求输入 PIN。

产品规则：启用 PIN 保护不等于启用应用锁屏。应用锁屏必须是独立的可选开关。

## 存储文件

默认数据目录：

```text
~/Library/Application Support/io.github.chumen.native-macos
```

重要文件：

- `settings.json`：运行设置。开启配置保护时以 age 保护数据保存。
- `profiles.json`：配置/订阅索引。开启配置保护时以 age 保护数据保存。
- `profiles/*.yaml`：导入的订阅或配置 YAML。开启配置保护时以 age 保护数据保存。
- `chumen-runtime.yaml`：生成给 mihomo 使用的运行配置。开启配置保护时，固定路径里保存的必须是 age 保护数据，不能留下明文。
- `pin-vault.json`：PIN 保险箱元数据和加密后的 age identity。它必须在解密设置前可读。
- `pin-auto-unlock.key`：默认不锁应用时用于自动解锁的本地随机包装密钥。开启应用锁屏时必须删除。
- `age-identity.json`：仅在用户关闭 PIN 保护时使用的本地明文 age identity。
- `logs/sidecar.log`：应用事件和 mihomo stdout/stderr 日志。安全和运行通知也要写入这里，但不能泄露秘密。
- `ipc/*.sock` 和 `ipc/*.pid`：本地运行期 IPC 和进程状态。

可选 Keychain 条目：

- `io.github.chumen.native-macos.pin-vault` / `age-key-vault`：可选 PIN 保险箱存储。
- `io.github.chumen.native-macos.config-protection` / `storage-master-key.age-identity`：兼容旧实现或可选 age identity 存储。
- `io.github.chumen.native-macos.ai` / `llm-api-key`：AI API Key 存储，和配置保护分离。

## PIN 保险箱规则

- PIN 保险箱使用每个 vault 独立随机 salt 做 PIN 派生。不能改成固定 salt。
- 默认自动解锁路径使用本地随机包装密钥，不使用硬编码秘密，也不使用固定 salt。
- 开启应用锁屏时，必须删除 auto-unlock 副本和包装密钥。
- 关闭应用锁屏时，只能在 age 私钥已经解锁的情况下重新创建 auto-unlock 副本。
- 旧版本 vault 如果没有 auto-unlock 副本，可以要求用户手动输入一次 PIN；成功解锁后，如果应用锁屏仍关闭，应补写 auto-unlock。
- 首次启动自动生成的 PIN 默认可见，因为它是应用为用户生成的。可以提供隐藏按钮，但不要默认展示两个一模一样的 PIN 输入框；只有用户切换到自定义密码流程时才需要确认输入。

## 运行配置规则

- Chumen 是 mihomo 指令和配置生成的编排方。
- mihomo 只应该收到当前运行所需的配置路径和环境变量。
- 任何无法避免的明文运行材料，都必须只写入当前会话拥有的随机临时目录，并由专门的清理逻辑清除。
- 固定 Application Support 运行配置路径可以存在，但开启配置保护时里面必须是受保护数据。
- 启动校验失败时，应记录命令上下文和脱敏后的 stderr/stdout。不要把 Go 堆栈或秘密材料直接塞进用户通知。

## AI 和搜索规则

- 没有可用模型 endpoint 或 Key 时，AI 助手退化为本地搜索。
- 本地 Ollama 是最快使用路径，不需要 API Key。
- 远程 OpenAI-compatible provider 可以要求保存 Key，但 Key 不能显示在 UI、日志、命令输出或通知里。
- AI 生成的修改只是提案。必须表现为临时待审核项，并提供类似 git 的 diff。
- 用户显式应用前，AI 不得直接修改配置、规则、代理/TUN 状态、系统代理状态或触发运行配置 reload。

## 日志和通知

- 每个用户可见的安全、内核启动、配置解密、配置加密、导入和运行失败通知，都必须同步写入 `logs/sidecar.log`。
- 日志应包含稳定标签、必要的文件路径和脱敏错误摘要。
- 日志不得包含 API Key、age 私钥、PIN、controller secret、带凭据的订阅 URL 或解密后的配置内容。

## UI 契约

首次启动安全流程必须让用户立刻理解：

- 保护对象是什么：配置文件和 age 私钥。
- age 私钥保存在哪里：默认本地文件，Keychain 可选。
- 启用 PIN 保护时，生成的 PIN 是什么。
- 应用锁屏是否开启。
- 不用 PIN 继续会发生什么：配置文件仍会加密，但 age 私钥会直接保存在所选位置，本机保护更弱。

不要把应用锁屏表现成启用 PIN 的默认后果。除非应用锁屏已开启，或旧 vault 缺少 auto-unlock 且需要一次迁移解锁，否则不要强制显示启动解锁页。
