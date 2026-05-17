---
description: "Use when editing Flutter screens, widgets, models, or services in the frontend. Covers state flow, UX safety, and consistency for inventory, scanner, and matchmaker features."
applyTo: "frontend/frontend/lib/**/*.dart"
---
# Frontend Flutter Instructions

- Keep state transitions readable and local unless the repo already centralizes them.
- Do not move parsing or API logic into presentation widgets unless the existing file already does that.
- Preserve current navigation and result-passing patterns for scanner and matchmaker flows.
- For review UIs, prefer editable recovery paths over silent data loss.
- When handling ticket items, keep quantity and price semantics explicit.
- Avoid broad visual refactors while fixing parser or flow bugs.