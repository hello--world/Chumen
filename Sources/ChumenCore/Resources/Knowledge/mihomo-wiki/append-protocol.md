---
title: Mihomo KB Append Protocol
category: convention
tags: [wiki, append, maintenance, ai]
status: current
---

# Mihomo KB Append Protocol

This page defines how AI agents should update `omx_wiki/`.

## When To Add Knowledge

Add or update wiki pages when:

- A new source-level fact is discovered.
- A debugging procedure is validated.
- A new feature path or extension recipe is learned.
- Existing documentation is wrong or incomplete.
- The user explicitly asks to add to the knowledge base.

Do not add:

- Guesses.
- Temporary hypotheses.
- External facts that are not needed for this repository.
- Large pasted logs unless summarized with source location.

## Page Format

Use this frontmatter:

```yaml
---
title: Human Title
category: architecture|decision|pattern|debugging|environment|session-log|reference|convention
tags: [short, searchable, tags]
source_files: [path/to/file.go]
status: current|needs-verification|deprecated
---
```

Recommended sections:

```markdown
# Title

## Canonical Facts

## Source Anchors

## Details

## Common Questions

## Update Notes
```

## Naming

Use lowercase kebab-case file names:

```text
omx_wiki/rule-engine.md
omx_wiki/provider-lifecycle.md
```

Update `omx_wiki/index.md` after adding a new page.

## Evidence Requirements

Each durable fact should have at least one of:

- Repository file path.
- Command output summary.
- Test result.
- Explicit user-provided requirement.

If not verified, mark:

```yaml
status: needs-verification
```

## Answering With This KB

When answering users:

1. Start from `index.md`.
2. Read the most relevant page.
3. If the answer depends on current source, inspect the source.
4. Cite file paths.
5. If a page is stale, update it or mention uncertainty.

## Update Log

When making meaningful KB changes, append a short entry to [[log]]:

```markdown
## YYYY-MM-DD - short title

- Changed: pages updated.
- Evidence: source files or commands.
- Reason: why the change was made.
```
