CREATE TABLE reviews (
  id           SERIAL      NOT NULL PRIMARY KEY,
  product_id   INT         NOT NULL REFERENCES products (id),
  customer_id  INT         NOT NULL REFERENCES users (id),
  rating       SMALLINT    NOT NULL CHECK (rating BETWEEN 1 AND 5),
  content      TEXT        NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (product_id, customer_id)
);
