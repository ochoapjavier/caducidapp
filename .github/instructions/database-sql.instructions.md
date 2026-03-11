---
description: "Use when editing SQL migrations, schema setup, indexes, or backend model changes that affect the database. Covers rollout safety, compatibility, and migration discipline."
applyTo: "database/**/*.sql, backend/scripts/**/*.sql"
---
# Database SQL Instructions

- Prefer additive migrations over destructive ones.
- Keep migration intent explicit: schema, data fix, index, rollback helper.
- Do not change old migrations unless the project explicitly uses a squash workflow.
- If adding indexes or constraints, explain the production reason.
- Keep backend model changes aligned with migration changes.