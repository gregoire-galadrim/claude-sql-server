-- =============================================================
-- MIGRATION CONSOLIDÉE — marketplace e-commerce (PostgreSQL)
-- Crée les extensions, la fonction trigger partagée, et les 11 tables
-- (migrations 001 à 011) dans l'ordre des dépendances (FK).
-- Compatible PostgreSQL 14+.
--
-- PRÉREQUIS : la base `test` doit exister.
--   - Avec Docker : créée automatiquement via POSTGRES_DB=test.
--   - Sans Docker : psql -U postgres -c "CREATE DATABASE test;"
--
-- EXÉCUTION connecté à la base `test` :
--   psql -U postgres -d test -f migration.sql
-- =============================================================

-- ------------------------------------------------------------------
-- 001 — EXTENSIONS + FONCTION TRIGGER PARTAGÉE
-- ------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ------------------------------------------------------------------
-- 002 — USERS
-- ------------------------------------------------------------------
CREATE TABLE users (
  id          SERIAL       NOT NULL PRIMARY KEY,
  email       VARCHAR(255) NOT NULL UNIQUE,
  username    VARCHAR(100) NOT NULL UNIQUE,
  full_name   VARCHAR(255) NOT NULL,
  role        VARCHAR(20)  NOT NULL CHECK (role IN ('customer', 'seller', 'admin')),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ------------------------------------------------------------------
-- 003 — CATEGORIES
-- ------------------------------------------------------------------
CREATE TABLE categories (
  id          SERIAL       NOT NULL PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  slug        VARCHAR(100) NOT NULL UNIQUE,
  parent_id   INT          NULL REFERENCES categories (id),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------
-- 004 — PRODUCTS
-- ------------------------------------------------------------------
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

-- ------------------------------------------------------------------
-- 005 — ADDRESSES
-- ------------------------------------------------------------------
CREATE TABLE addresses (
  id           SERIAL       NOT NULL PRIMARY KEY,
  user_id      INT          NOT NULL REFERENCES users (id),
  street       VARCHAR(255) NOT NULL,
  city         VARCHAR(100) NOT NULL,
  postal_code  VARCHAR(20)  NOT NULL,
  country      VARCHAR(100) NOT NULL DEFAULT 'France',
  is_default   BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------
-- 006 — ORDERS
-- ------------------------------------------------------------------
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

-- ------------------------------------------------------------------
-- 007 — ORDER_ITEMS
-- ------------------------------------------------------------------
CREATE TABLE order_items (
  id          SERIAL         NOT NULL PRIMARY KEY,
  order_id    INT            NOT NULL REFERENCES orders (id),
  product_id  INT            NOT NULL REFERENCES products (id),
  quantity    INT            NOT NULL CHECK (quantity > 0),
  unit_price  NUMERIC(10, 2) NOT NULL,
  created_at  TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- NOTE : PostgreSQL ne crée PAS d'index automatique sur les colonnes de clé étrangère
-- (order_id, product_id). Même comportement que SQL Server, inverse de MySQL/InnoDB.

-- ------------------------------------------------------------------
-- 008 — REVIEWS
-- ------------------------------------------------------------------
CREATE TABLE reviews (
  id           SERIAL      NOT NULL PRIMARY KEY,
  product_id   INT         NOT NULL REFERENCES products (id),
  customer_id  INT         NOT NULL REFERENCES users (id),
  rating       SMALLINT    NOT NULL CHECK (rating BETWEEN 1 AND 5),
  content      TEXT        NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (product_id, customer_id)
);

-- ------------------------------------------------------------------
-- 009 — INVENTORY
-- ------------------------------------------------------------------
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

-- ------------------------------------------------------------------
-- 010 — PAYMENTS
-- ------------------------------------------------------------------
CREATE TABLE payments (
  id               SERIAL         NOT NULL PRIMARY KEY,
  order_id         INT            NOT NULL REFERENCES orders (id),
  amount           NUMERIC(10, 2) NOT NULL,
  method           VARCHAR(30)    NOT NULL CHECK (
                     method IN ('credit_card', 'paypal', 'bank_transfer', 'crypto')
                   ),
  status           VARCHAR(20)    NOT NULL CHECK (
                     status IN ('pending', 'completed', 'failed', 'refunded')
                   ),
  transaction_ref  VARCHAR(255)   NULL,
  created_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------
-- 011 — TAGS + PRODUCT_TAGS
-- ------------------------------------------------------------------
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
