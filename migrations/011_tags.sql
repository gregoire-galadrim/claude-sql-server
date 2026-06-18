CREATE TABLE tags (
  id          INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name        NVARCHAR(50) NOT NULL UNIQUE,
  created_at  DATETIME2    NOT NULL CONSTRAINT df_tags_created_at DEFAULT SYSDATETIME()
);
GO

CREATE TABLE product_tags (
  product_id  INT NOT NULL,
  tag_id      INT NOT NULL,
  CONSTRAINT pk_product_tags PRIMARY KEY (product_id, tag_id),
  CONSTRAINT fk_product_tags_product FOREIGN KEY (product_id) REFERENCES products (id),
  CONSTRAINT fk_product_tags_tag     FOREIGN KEY (tag_id)     REFERENCES tags (id)
);
GO
