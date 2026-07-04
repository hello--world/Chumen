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

Prefer concise file headers, type comments, focused doc comments, or nearby README notes. Do not comment obvious line-by-line mechanics; explain the reason, invariant, lifecycle, security boundary, or tradeoff that is not obvious from the code itself. Update or remove stale intent notes when changing the design.
