CREATE TABLE reviews (
  id           INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  product_id   INT           NOT NULL,
  customer_id  INT           NOT NULL,
  rating       TINYINT       NOT NULL CONSTRAINT ck_reviews_rating CHECK (rating BETWEEN 1 AND 5),
  content      NVARCHAR(MAX) NULL,
  created_at   DATETIME2     NOT NULL CONSTRAINT df_reviews_created_at DEFAULT SYSDATETIME(),
  CONSTRAINT uq_reviews_product_customer UNIQUE (product_id, customer_id),
  CONSTRAINT fk_reviews_product  FOREIGN KEY (product_id)  REFERENCES products (id),
  CONSTRAINT fk_reviews_customer FOREIGN KEY (customer_id) REFERENCES users (id)
);
GO
