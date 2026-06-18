CREATE TABLE orders (
  id                   INT            NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  customer_id          INT            NOT NULL,
  shipping_address_id  INT            NULL,
  status               NVARCHAR(30)   NOT NULL CONSTRAINT ck_orders_status CHECK (
                         status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled', 'refunded')
                       ),
  total_amount         DECIMAL(10, 2) NOT NULL,
  created_at           DATETIME2      NOT NULL CONSTRAINT df_orders_created_at DEFAULT SYSDATETIME(),
  updated_at           DATETIME2      NOT NULL CONSTRAINT df_orders_updated_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)         REFERENCES users (id),
  CONSTRAINT fk_orders_address  FOREIGN KEY (shipping_address_id) REFERENCES addresses (id)
);
GO

-- NOTE INTENTIONNELLE : pas d'index sur status ni sur created_at.
-- Contrairement à MySQL/InnoDB, SQL Server ne crée AUCUN index automatique sur les
-- colonnes de clé étrangère (customer_id, shipping_address_id) ni sur les colonnes de
-- filtre métier (status, created_at). Seules la PK et les contraintes UNIQUE sont indexées.
-- C'est exactement le problème de performance que les apprenants doivent diagnostiquer.
CREATE TRIGGER trg_orders_updated_at ON orders AFTER UPDATE AS
BEGIN
  SET NOCOUNT ON;
  UPDATE o SET updated_at = SYSDATETIME()
  FROM orders o INNER JOIN inserted i ON o.id = i.id;
END;
GO
