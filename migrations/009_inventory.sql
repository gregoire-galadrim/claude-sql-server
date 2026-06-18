CREATE TABLE inventory (
  id                 INT       NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  product_id         INT       NOT NULL UNIQUE,
  quantity           INT       NOT NULL CONSTRAINT ck_inventory_quantity CHECK (quantity >= 0),
  reorder_threshold  INT       NOT NULL CONSTRAINT df_inventory_reorder DEFAULT 10,
  updated_at         DATETIME2 NOT NULL CONSTRAINT df_inventory_updated_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES products (id)
);
GO

CREATE TRIGGER trg_inventory_updated_at ON inventory AFTER UPDATE AS
BEGIN
  SET NOCOUNT ON;
  UPDATE inv SET updated_at = SYSDATETIME()
  FROM inventory inv INNER JOIN inserted i ON inv.id = i.id;
END;
GO
