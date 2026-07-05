# Chumen Agent Notes

## Commit Message Style

Use concise conventional-commit subjects and evidence-oriented bodies. When a commit needs context, prefer this structure:

```text
type(scope): 摘要

说明这次修改解决的问题、关键结论和最终路径。

Constraint: 必须遵守的约束。

Rejected: 放弃的方案 | 放弃原因。

Confidence: high|medium|low

Scope-risk: low|medium|high

Directive: 后续相关修改必须同步遵守或更新的规则。

Tested: 具体执行过的验证命令
```

Keep `Constraint` and `Rejected` focused on engineering decisions that prevent future misdiagnosis or regressions. Do not list routine implementation detail as a directive.

## Code Intent Notes

Every new module or non-trivial feature must leave intent close to the code so future humans and AI agents can understand why it exists. Record the problem being solved, the key design choice, important constraints, and rejected alternatives when they affect maintenance.

Use comments generously at module boundaries, feature entry points, state machines, security/privacy boundaries, async lifecycles, migrations, and non-obvious UI flows. Prefer concise file headers, type comments, focused doc comments, and section comments that explain how the pieces fit together for future AI readers. Do not comment obvious line-by-line mechanics; explain the reason, invariant, lifecycle, security boundary, or tradeoff that is not obvious from the code itself. Update or remove stale intent notes when changing the design.

## Operational Memory / 操作记忆

Before changing important UI or runtime behavior, plan the data ownership, refresh cadence, state boundary, and verification path. Do not patch only the visible screenshot symptom. Keep shared status surfaces such as dashboard, header, status bar, and settings backed by reusable protocols or update modules instead of scattered page-local timers.

修改重要 UI 或运行时行为前，必须先规划数据归属、更新频率、状态边界和验证路径，不要只针对截图表象局部硬改。总览、顶部状态、状态栏和设置页这类共享状态界面，应复用统一协议或更新模块，避免页面各自维护零散定时器。

System proxy status is app-level external state and should be refreshed by the shared update coordinator. Core connections, traffic, and memory are runtime state and should refresh only while the core is running. Custom core process names must use a Chumen-controlled `chumen-` launch path, preferably as a symlink to the real core rather than a copied binary.

系统代理状态属于应用级外部状态，应由统一更新调度器刷新；连接、流量、内存属于内核运行态，只应在内核运行时刷新。自定义内核进程名必须通过 Chumen 受控的 `chumen-` 启动路径实现，优先使用指向真实 core 的符号链接，不要复制二进制副本造成陈旧文件或升级不一致。

UI focus states must reflect real interaction. An unfocused search entry should not show a blue keyboard focus ring; the input focus state belongs only to the active search overlay. After changes, run `swift build`, relevant tests or `swift test`, and `git diff --check`; visual behavior requires restarting the app and checking the window.

UI 焦点态必须反映真实交互状态。未聚焦的搜索入口不应显示蓝色键盘焦点框；输入焦点只属于已打开的搜索浮层。修改完成后必须运行 `swift build`、相关测试或 `swift test`、`git diff --check`；视觉行为必须重启 app 并检查窗口。

## Documentation Language Style

Project documentation that is written or substantially edited by agents must have both Chinese and English versions. Prefer paired files such as `README.zh.md` / `README.en.md` and keep the stable root file, for example `README.md`, as a language router. Update both language files in the same change.

代理新增或大幅修改项目文档时，必须同时提供中文和英文版本。优先使用 `README.zh.md` / `README.en.md` 这类成对文件，并保留 `README.md` 作为语言入口。同一次修改必须同步更新两个语言文件。
