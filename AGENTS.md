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

## Documentation Language Style

Project documentation that is written or substantially edited by agents must have both Chinese and English versions. Prefer paired files such as `README.zh.md` / `README.en.md` and keep the stable root file, for example `README.md`, as a language router. Update both language files in the same change.

代理新增或大幅修改项目文档时，必须同时提供中文和英文版本。优先使用 `README.zh.md` / `README.en.md` 这类成对文件，并保留 `README.md` 作为语言入口。同一次修改必须同步更新两个语言文件。
