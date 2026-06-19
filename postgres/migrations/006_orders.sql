CREATE TABLE orders (
  id                   SERIAL         NOT NULL PRIMARY KEY,
  customer_id          INT            NOT NULL REFERENCES users (id),
  shipping_address_id  INT            NULL REFERENCES addresses (id),
  status               VARCHAR(30)    NOT NULL CHECK (
                         status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled', 'refunded')
                       ),
  total_amount         NUMERIC(10, 2) NOT NULL,
  created_at           TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- NOTE INTENTIONNELLE : pas d'index sur status ni sur created_at.
-- Contrairement à MySQL/InnoDB, PostgreSQL ne crée AUCUN index automatique sur les
-- colonnes de clé étrangère (customer_id, shipping_address_id) ni sur les colonnes de
-- filtre métier (status, created_at). Seuls la PK et les contraintes UNIQUE sont indexés.
-- C'est exactement le problème de performance que les apprenants doivent diagnostiquer.

CREATE TRIGGER trg_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
