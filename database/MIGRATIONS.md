# Database Migrations

This folder tracks manual SQL migrations for the production Postgres (Supabase).

If you're not using Alembic yet, paste these scripts into the Supabase SQL editor
or run them via `psql` with your connection string. Keep one file per change-set.

## 2025-11-17 add indexes

File: `migrations/2025-11-17_add_indexes.sql`

Purpose:
- Speed up common queries without changing table shapes.
- Matches ORM changes that set `index=True` and added composite `Index(...)`.

Statements:
- `ix_producto_maestro_nombre` on `producto_maestro(nombre)`
- `ix_producto_user_nombre` on `producto_maestro(user_id, nombre)`
- `ix_inventario_stock_fecha_caducidad` on `inventario_stock(fecha_caducidad)`
- `ix_stock_user_fecha` on `inventario_stock(user_id, fecha_caducidad)`

How to apply (Supabase SQL Editor):
1. Open Supabase project > SQL > New query.
2. Paste the content of `migrations/2025-11-17_add_indexes.sql`.
3. Run. If an index already exists with that name, `IF NOT EXISTS` avoids errors.

How to apply (psql, optional):
```sh
# Replace with your DSN
psql "postgres://USER:PASSWORD@HOST:PORT/DB" -v ON_ERROR_STOP=1 -f database/migrations/2025-11-17_add_indexes.sql
```

Notes:
- These are lightweight and safe on small datasets. For very large tables,
  consider `CREATE INDEX CONCURRENTLY` one-by-one outside a transaction.
- No schema changes (tables/columns) are made; only indexes are added.
