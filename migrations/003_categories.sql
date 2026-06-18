CREATE TABLE categories (
  id          INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name        NVARCHAR(100) NOT NULL,
  slug        NVARCHAR(100) NOT NULL UNIQUE,
  parent_id   INT           NULL,
  created_at  DATETIME2     NOT NULL CONSTRAINT df_categories_created_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id) REFERENCES categories (id)
);
GO
