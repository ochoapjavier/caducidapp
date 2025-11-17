# Backend architecture (FastAPI)

This backend follows a simple layered architecture to keep things readable, scalable, and maintainable.

- routers/  — HTTP endpoints (thin). Validate input/output via Pydantic schemas, wire dependencies, set status codes and tags.
- services/ — Business logic (thick). Coordinates repositories, enforces rules, orchestrates multi-step operations.
- repositories/ — Data access. SQLAlchemy ORM queries, persistence, and mapping to domain models.
- models.py — SQLAlchemy models (tables, columns, indexes, relationships).
- schemas/ — Pydantic models used as request/response contracts (input/output to/from the API).
- auth/ — Authentication dependencies (Firebase in this project).
- database/ — Engine, Base, and SQL scripts (init + manual migrations).

## Schemas: request vs response

Keep request and response models separate. It gives you clarity and backwards-compatibility when the API evolves.

- Response (read) models describe what the API returns.
- Request (write) models describe what the API accepts for create/update operations.

Naming conventions used here:

- <Entity>          — response (read) model, e.g. `Product`, `StockItem`
- <Entity>Create    — request (write) model for create, e.g. `StockItemCreate`, `LocationCreate`
- <Entity>Update    — request (write) model for update, e.g. `ProductUpdate`
- ActionPayload     — request models for non-CRUD actions, e.g. `StockRemove`

This results in the following schemas:
- schemas/product_update.py
  - `ProductUpdate` (request)
- schemas/item.py (stock-related)
  - `StockItem` (response: a stock item with nested `ProductSchema` and `LocationSchema`)
  - `StockAlertItem` (response variant for alerts)
  - `StockItemCreate`, `StockItemCreateFromScan` (request)
  - `ProductSchema`, `LocationSchema` (nested response objects)
- schemas/stock_update.py
  - `StockUpdate` (request: update stock fields such as `product_name`, `brand`, `fecha_caducidad`, `cantidad_actual`, `ubicacion_id`)
  - `StockRemove` (request: remove a quantity from an existing stock item)
- schemas/ubicacion.py
  - `LocationBase`, `LocationCreate` (request)
  - `Location` (response)
- schemas/alert.py
  - `AlertResponse` (response for alerts)

Why `ProductUpdate` and `StockUpdate`?

- They are update inputs for two different resources:
  - ProductUpdate applies to the product catalog entry (nombre/marca of the master product).
  - StockUpdate applies to a specific stock row (lote/fecha/cantidad/ubicación) and optionally allows changing the associated product's name/brand for convenience.
- We keep product and stock updates separate because they have different lifecycles and authorization/validation rules.
- The name `Payload` is used when the request does not map 1:1 to a single entity or follows an action-style update (e.g., partial PATCH with optional fields). If you prefer symmetric naming, it could also be `StockUpdate`.

Note on `Item` vs `Stock` naming

- Historically, the project used `Item` to mean a stock entry (one product in a specific location with an expiration date). We migrated to `StockItem` and `StockItemCreate` for clarity and symmetry.

## Routers: keep them thin

Routers should:
- Declare `response_model` and request models from `schemas`.
- Resolve dependencies (DB session, user id).
- Call a single service method and return its result.

Example (stock):
- POST /inventory/stock/manual → `StockItemCreate` → returns `StockItem`
- POST /inventory/stock/from-scan → `StockItemCreateFromScan` → returns `StockItem`
- GET /inventory/stock → returns `List[StockItem]`
- POST /inventory/stock/remove → `StockRemove`
- PATCH /inventory/stock/{id_stock} → `StockUpdate` → returns `StockItem`

## Services: business logic lives here

- Implement invariants (e.g., reducing quantity to 0 deletes the stock item).
- Coordinate product/stock updates in a single transaction.
- Provide readable method names called from routers.

## Repositories: isolate SQL

- Only repositories know about SQLAlchemy queries.
- Return ORM objects to services which then map to Pydantic response models via `from_attributes=True`.

## Models: ORM shape and indexes

- Relationships use `back_populates` to enable navigation from both sides.
- Lightweight indexes are defined for common queries (alerts by date, product lookup by name).

## Authentication

- `auth/firebase_auth.py` provides dependencies to extract the current user id from Firebase tokens.

## Database migration policy

- Manual migration scripts live in `database/migrations/` and are idempotent when possible.
- Document each change in `database/MIGRATIONS.md`.

## Style and import rules adopted

- No Pydantic models inside routers. All request/response models live in `schemas/`.
- Package-level exports in `schemas/__init__.py` to allow concise imports: `from schemas import Item, ProductUpdate, ...`.
- Routers avoid importing from other routers/services to prevent circular imports.
- Services do not import routers.
