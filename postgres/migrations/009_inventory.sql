CREATE TABLE inventory (
  id                 SERIAL      NOT NULL PRIMARY KEY,
  product_id         INT         NOT NULL UNIQUE REFERENCES products (id),
  quantity           INT         NOT NULL CHECK (quantity >= 0),
  reorder_threshold  INT         NOT NULL DEFAULT 10,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_inventory_updated_at
  BEFORE UPDATE ON inventory
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
