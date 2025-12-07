-- database/migrations/2025-12-04_shopping_list.sql

CREATE TABLE shopping_list_items (
    id SERIAL PRIMARY KEY,
    hogar_id INTEGER REFERENCES hogares(id_hogar) ON DELETE CASCADE NOT NULL,
    producto_nombre VARCHAR(255) NOT NULL,
    fk_producto INTEGER REFERENCES producto_maestro(id_producto) ON DELETE SET NULL,
    cantidad INTEGER DEFAULT 1 NOT NULL,
    completado BOOLEAN DEFAULT FALSE NOT NULL,
    added_by VARCHAR(255) NOT NULL, -- Firebase UID
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_shopping_list_hogar ON shopping_list_items(hogar_id);
CREATE INDEX ix_shopping_list_completado ON shopping_list_items(completado);
