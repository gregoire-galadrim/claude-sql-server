CREATE TABLE products (
  id           INT            NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  seller_id    INT            NOT NULL,
  category_id  INT            NOT NULL,
  name         NVARCHAR(255)  NOT NULL,
  description  NVARCHAR(MAX)  NULL,
  price        DECIMAL(10, 2) NOT NULL CONSTRAINT ck_products_price CHECK (price >= 0),
  is_active    BIT            NOT NULL CONSTRAINT df_products_is_active DEFAULT 1,
  created_at   DATETIME2      NOT NULL CONSTRAINT df_products_created_at DEFAULT SYSDATETIME(),
  updated_at   DATETIME2      NOT NULL CONSTRAINT df_products_updated_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_products_seller   FOREIGN KEY (seller_id)   REFERENCES users (id),
  CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories (id)
);
GO

CREATE TRIGGER trg_products_updated_at ON products AFTER UPDATE AS
BEGIN
  SET NOCOUNT ON;
  UPDATE p SET updated_at = SYSDATETIME()
  FROM products p INNER JOIN inserted i ON p.id = i.id;
END;
GO
