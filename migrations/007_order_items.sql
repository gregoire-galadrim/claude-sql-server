CREATE TABLE order_items (
  id          INT            NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  order_id    INT            NOT NULL,
  product_id  INT            NOT NULL,
  quantity    INT            NOT NULL CONSTRAINT ck_order_items_quantity CHECK (quantity > 0),
  unit_price  DECIMAL(10, 2) NOT NULL,
  created_at  DATETIME2      NOT NULL CONSTRAINT df_order_items_created_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_order_items_order   FOREIGN KEY (order_id)   REFERENCES orders (id),
  CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products (id)
);
GO

-- NOTE : SQL Server ne crée PAS d'index automatique sur les colonnes de clé étrangère
-- (order_id, product_id). C'est le comportement de PostgreSQL, et l'inverse de MySQL/InnoDB
-- qui indexe automatiquement chaque FK — différence fondamentale à connaître.
