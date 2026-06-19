CREATE TABLE products (
  id           SERIAL         NOT NULL PRIMARY KEY,
  seller_id    INT            NOT NULL REFERENCES users (id),
  category_id  INT            NOT NULL REFERENCES categories (id),
  name         VARCHAR(255)   NOT NULL,
  description  TEXT           NULL,
  price        NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
  is_active    BOOLEAN        NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
