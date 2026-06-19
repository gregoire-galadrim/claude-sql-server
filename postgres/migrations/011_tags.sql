CREATE TABLE tags (
  id          SERIAL      NOT NULL PRIMARY KEY,
  name        VARCHAR(50) NOT NULL UNIQUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE product_tags (
  product_id  INT NOT NULL REFERENCES products (id),
  tag_id      INT NOT NULL REFERENCES tags (id),
  PRIMARY KEY (product_id, tag_id)
);
