# AI Setup For Caducidapp

This folder provides a practical AI customization baseline for the project.

## Included

- `copilot-instructions.md`: repository-wide guardrails.
- `instructions/`: domain instructions for backend, frontend, database, and receipts OCR.
- `agents/`: specialized agents for backend, frontend, receipts, review, and orchestration.
- `prompts/`: reusable prompt entrypoints for common workflows.

## Recommended Usage

- Use the default agent for general work and small tasks.
- Switch to `Backend Specialist` for FastAPI, services, repositories, auth, and schemas.
- Switch to `Frontend Specialist` for Flutter screens, widgets, UI flows, and models.
- Switch to `Receipts Specialist` for OCR, parser heuristics, discounts, quantities, and ticket matching.
- Use `Orchestrator` when a task spans backend plus frontend or requires routing to multiple specialists.
- Use `Reviewer` before merging risky changes.

## Suggested Next Layer

1. Add a `backend-tests.prompt.md` for endpoint or service test generation.
2. Add a `migration-review.prompt.md` for schema changes.
3. Add skills when you want multi-step workflows, especially for receipt debugging and end-to-end feature delivery.
4. Add hooks later for deterministic checks such as focused `flutter analyze`, Python linting, or blocking dangerous commands.

## Suggested Team Workflow

1. Start feature work with `Feature End To End`.
2. Debug receipt issues with `Debug Ticket OCR`.
3. Run `Review Changes` before merge.
4. Keep refining instructions as the repo architecture becomes more stable.

## Notes

- Keep descriptions keyword-rich so Copilot can discover the right file or agent.
- Avoid duplicate rules across files.
- Prefer a few strong customizations over many weak ones.