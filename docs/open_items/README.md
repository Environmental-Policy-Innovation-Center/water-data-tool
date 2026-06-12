# Open Items

This directory contains living documents for known issues, discovery work, and planned
improvements that have not yet been fully resolved or ticketed. They exist to capture
context so that anyone — now or later — can pick up the work without losing the reasoning
behind it.

---

## Lifecycle

1. **Create** a doc here when you discover something worth tracking: a known bug, a tech debt
   item, a migration that needs to happen, an audit that surfaced issues, or a design question
   that needs answering before implementation.
2. **Update** the doc as work progresses — add findings, refine the plan, check off steps.
3. **Delete** the doc when the work is complete. Reference the closing PR in the commit message.
   There is no archive — git history is the archive.

---

## Document Format

Every document starts with a `Context` section that answers **what** this is and **why** it
matters. This alone makes the doc useful to someone who has never seen the issue before.

Below `Context`, use whichever sections apply:

- **`Discovery`** — for investigative work. Use this when the problem is understood but the
  solution isn't fully defined yet. Include findings, open questions, audit results, ecosystem
  maps, and anything that needs to be figured out before implementation can start.

- **`Implementation Guide`** — for work that is ready to be done. Include code changes,
  architecture decisions, step-by-step instructions, and a checklist.

Both sections can coexist in the same doc when a piece of work has a discovery phase followed
by a known implementation plan (see `ETL_DEPLOY_INVESTIGATION.md`).

End every doc with the cleanup footer so whoever finishes the work knows to delete it.

```markdown
# Title

## Context

### What
What is this? One or two sentences.

### Why
Why does it matter? What breaks or degrades without it?

## Discovery
Findings, open questions, audit results, ecosystem maps.

## Implementation Guide
Code changes, architecture decisions, steps, checklist.

---

> **Cleanup:** Delete this file when resolved. Reference the closing PR in the commit message.
```

Not every document needs every section — use judgment. An informal list of small TODOs
(like `OPEN_WORK_ITEMS.md`) doesn't need this structure. A multi-week migration with
external dependencies (like `TIGER_ETL_SOURCE_MIGRATION.md`) does.

---

## Current Documents

| Document | What it covers |
|---|---|
| `ETL_DEPLOY_INVESTIGATION.md` | ETL pipeline stability, 504 root cause, ECS ecosystem map, action plan |
| `TIGER_ETL_SOURCE_MIGRATION.md` | Migrating `CartographicBoundaries` TIGER source URLs from Census.gov to S3 |
| `TEXT_COLOR_AUDIT.md` | Neutral color token consistency audit — remaining `gray-*` and off-scale `neutral-*` usages |
| `DRAG_DROP_SORTABLE_JS.md` | SortableJS implementation guide for drag-and-drop column and category reordering |
| `NICE_TO_HAVES.md` | Lower-priority improvements and feature gaps not yet ticketed |
| `REMEMBER_TO.md` | Documentation gaps and things to write up |
