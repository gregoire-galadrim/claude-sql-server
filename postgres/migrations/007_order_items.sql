CREATE TABLE order_items (
  id          SERIAL         NOT NULL PRIMARY KEY,
  order_id    INT            NOT NULL REFERENCES orders (id),
  product_id  INT            NOT NULL REFERENCES products (id),
  quantity    INT            NOT NULL CHECK (quantity > 0),
  unit_price  NUMERIC(10, 2) NOT NULL,
  created_at  TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- NOTE : PostgreSQL ne crée PAS d'index automatique sur les colonnes de clé étrangère
-- (order_id, product_id). C'est le même comportement que SQL Server, et l'inverse de
-- MySQL/InnoDB qui indexe automatiquement chaque FK — différence fondamentale à connaître.
