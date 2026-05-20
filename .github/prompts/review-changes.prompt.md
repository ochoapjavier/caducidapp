---
name: "Review Changes"
description: "Review current repository changes for bugs, regressions, risks, and missing validation, using a reviewer-first mindset."
agent: "Reviewer"
argument-hint: "Optionally specify the area to review: backend, frontend, receipts, or whole repo"
---
Review the current changes in the repository.

Requirements:
- Prioritize bugs, regressions, and risky assumptions.
- Keep findings concrete and actionable.
- Mention validation gaps if tests or focused checks are missing.

Return findings first, then a short summary if needed.