# Caducidapp Copilot Instructions

This repository contains a FastAPI backend, a Flutter frontend, SQL migrations, and a receipt OCR/matching workflow.

## Architecture

- Backend structure is router -> service -> repository. Keep HTTP concerns in routers, business rules in services, and persistence logic in repositories.
- Frontend structure is screen -> service/model -> widget. Do not push parsing or API orchestration into widgets unless the file already follows that pattern.
- Receipt parsing is a domain-specific subsystem. Prefer targeted heuristics per supermarket over generic regex-only parsing.
- Database changes must stay compatible with existing migrations and current production assumptions.

## Working Rules

- Make focused changes. Do not refactor unrelated code while fixing a bug.
- Preserve existing naming, style, and public API shape unless the change requires otherwise.
- When working on OCR or parsing, validate against real logs and ticket images, not only against guessed layouts.
- When working on inventory or matching flows, avoid regressions in quantity, discount, and product identity handling.
- If a change spans backend and frontend, keep the data contract explicit and verify both sides.

## Backend Rules

- Use clear request and response schemas.
- Keep auth and hogar scoping explicit.
- Avoid hidden database side effects in routers.
- For migrations, prefer additive changes and safe rollout patterns.

## Frontend Rules

- Keep UI edits small and consistent with the current app.
- Prefer readable state transitions over clever abstractions.
- When parsing ticket items for UI review, preserve enough information for later correction by the user.

## Receipt Parsing Rules

- Distinguish original line totals, discounts, quantities, and weight-detail rows.
- Never merge OCR rows across chunks by coordinates from separate crops.
- Stop parsing before totals, VAT tables, receipt footer, and coupon sections.
- If an item is detected but later filtered out, inspect unit/total discount logic before changing row grouping.

## Validation

- Backend: run targeted validation or tests when touching API or DB logic.
- Frontend: run focused `flutter analyze` on changed files when practical.
- Parsing: compare logs against the actual ticket layout whenever available.