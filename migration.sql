-- =============================================================
-- MIGRATION CONSOLIDÉE — marketplace e-commerce (SQL Server / T-SQL)
-- Crée la base `test`, s'y connecte, puis crée les 11 tables (migrations
-- 001 à 011) dans l'ordre des dépendances (FK).
-- Compatible SQL Server 2019+ (testé sur SQL Server 2022).
--
-- EXÉCUTION : lancer ce fichier comme un SCRIPT (instruction par instruction),
-- p. ex. dans DBeaver via « Execute SQL Script » (Alt+X), ou sqlcmd.
-- Le client exécute chaque instruction (séparée par `;`) sur la même connexion :
-- CREATE DATABASE puis USE puis CREATE TABLE s'enchaînent correctement.
--
-- Ce fichier ne contient AUCUN séparateur `GO` : `GO` est une directive du
-- client (sqlcmd / SSMS), pas une instruction T-SQL. Les clients JDBC
-- (DBeaver, etc.) l'envoient au serveur tel quel et il est rejeté. Les triggers
-- — qui doivent normalement ouvrir un batch — sont donc créés via EXEC('...').
--
-- 001_extensions : aucune extension requise pour SQL Server.
-- =============================================================

-- ------------------------------------------------------------------
-- 000 — BASE : création + connexion
-- ------------------------------------------------------------------
IF DB_ID('test') IS NULL
  CREATE DATABASE test;

USE test;

-- ------------------------------------------------------------------
-- 002 — USERS
-- ------------------------------------------------------------------
CREATE TABLE users (
  id          INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  email       NVARCHAR(255) NOT NULL UNIQUE,
  username    NVARCHAR(100) NOT NULL UNIQUE,
  full_name   NVARCHAR(255) NOT NULL,
  role        NVARCHAR(20)  NOT NULL CONSTRAINT ck_users_role CHECK (role IN ('customer', 'seller', 'admin')),
  created_at  DATETIME2     NOT NULL CONSTRAINT df_users_created_at DEFAULT SYSDATETIME(),
  updated_at  DATETIME2     NOT NULL CONSTRAINT df_users_updated_at DEFAULT SYSDATETIME()
);

-- Équivalent de "ON UPDATE CURRENT_TIMESTAMP" (MySQL) : reproduit via un trigger.
EXEC(N'CREATE TRIGGER trg_users_updated_at ON users AFTER UPDATE AS
BEGIN
  SET NOCOUNT ON;
  UPDATE u SET updated_at = SYSDATETIME()
  FROM users u INNER JOIN inserted i ON u.id = i.id;
END;');

-- ------------------------------------------------------------------
-- 003 — CATEGORIES
-- ------------------------------------------------------------------
CREATE TABLE categories (
  id          INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name        NVARCHAR(100) NOT NULL,
  slug        NVARCHAR(100) NOT NULL UNIQUE,
  parent_id   INT           NULL,
  created_at  DATETIME2     NOT NULL CONSTRAINT df_categories_created_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id) REFERENCES categories (id)
);

-- ------------------------------------------------------------------
-- 004 — PRODUCTS
-- ------------------------------------------------------------------
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

EXEC(N'CREATE TRIGGER trg_products_updated_at ON products AFTER UPDATE AS
BEGIN
  SET NOCOUNT ON;
  UPDATE p SET updated_at = SYSDATETIME()
  FROM products p INNER JOIN inserted i ON p.id = i.id;
END;');

-- ------------------------------------------------------------------
-- 005 — ADDRESSES
-- ------------------------------------------------------------------
CREATE TABLE addresses (
  id           INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  user_id      INT           NOT NULL,
  street       NVARCHAR(255) NOT NULL,
  city         NVARCHAR(100) NOT NULL,
  postal_code  NVARCHAR(20)  NOT NULL,
  country      NVARCHAR(100) NOT NULL CONSTRAINT df_addresses_country DEFAULT N'France',
  is_default   BIT           NOT NULL CONSTRAINT df_addresses_is_default DEFAULT 0,
  created_at   DATETIME2     NOT NULL CONSTRAINT df_addresses_created_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_addresses_user FOREIGN KEY (user_id) REFERENCES users (id)
);

-- ------------------------------------------------------------------
-- 006 — ORDERS
-- ------------------------------------------------------------------
CREATE TABLE orders (
  id                   INT            NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  customer_id          INT            NOT NULL,
  shipping_address_id  INT            NULL,
  status               NVARCHAR(30)   NOT NULL CONSTRAINT ck_orders_status CHECK (
                         status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled', 'refunded')
                       ),
  total_amount         DECIMAL(10, 2) NOT NULL,
  created_at           DATETIME2      NOT NULL CONSTRAINT df_orders_created_at DEFAULT SYSDATETIME(),
  updated_at           DATETIME2      NOT NULL CONSTRAINT df_orders_updated_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)         REFERENCES users (id),
  CONSTRAINT fk_orders_address  FOREIGN KEY (shipping_address_id) REFERENCES addresses (id)
);

-- NOTE INTENTIONNELLE : pas d'index sur status ni sur created_at.
-- Contrairement à MySQL/InnoDB, SQL Server ne crée AUCUN index automatique sur les
-- colonnes de clé étrangère (customer_id, shipping_address_id) ni sur les colonnes de
-- filtre métier (status, created_at). Seules la PK et les contraintes UNIQUE sont indexées.
-- C'est exactement le problème de performance que les apprenants doivent diagnostiquer.
EXEC(N'CREATE TRIGGER trg_orders_updated_at ON orders AFTER UPDATE AS
BEGIN
  SET NOCOUNT ON;
  UPDATE o SET updated_at = SYSDATETIME()
  FROM orders o INNER JOIN inserted i ON o.id = i.id;
END;');

-- ------------------------------------------------------------------
-- 007 — ORDER_ITEMS
-- ------------------------------------------------------------------
CREATE TABLE order_items (
  id          INT            NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  order_id    INT            NOT NULL,
  product_id  INT            NOT NULL,
  quantity    INT            NOT NULL CONSTRAINT ck_order_items_quantity CHECK (quantity > 0),
  unit_price  DECIMAL(10, 2) NOT NULL,
  created_at  DATETIME2      NOT NULL CONSTRAINT df_order_items_created_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_order_items_order   FOREIGN KEY (order_id)   REFERENCES orders (id),
  CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products (id)
);

-- NOTE : SQL Server ne crée PAS d'index automatique sur les colonnes de clé étrangère
-- (order_id, product_id). C'est le comportement de PostgreSQL, et l'inverse de MySQL/InnoDB
-- qui indexe automatiquement chaque FK — différence fondamentale à connaître.

-- ------------------------------------------------------------------
-- 008 — REVIEWS
-- ------------------------------------------------------------------
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

-- ------------------------------------------------------------------
-- 009 — INVENTORY
-- ------------------------------------------------------------------
CREATE TABLE inventory (
  id                 INT       NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  product_id         INT       NOT NULL UNIQUE,
  quantity           INT       NOT NULL CONSTRAINT ck_inventory_quantity CHECK (quantity >= 0),
  reorder_threshold  INT       NOT NULL CONSTRAINT df_inventory_reorder DEFAULT 10,
  updated_at         DATETIME2 NOT NULL CONSTRAINT df_inventory_updated_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES products (id)
);

EXEC(N'CREATE TRIGGER trg_inventory_updated_at ON inventory AFTER UPDATE AS
BEGIN
  SET NOCOUNT ON;
  UPDATE inv SET updated_at = SYSDATETIME()
  FROM inventory inv INNER JOIN inserted i ON inv.id = i.id;
END;');

-- ------------------------------------------------------------------
-- 010 — PAYMENTS
-- ------------------------------------------------------------------
CREATE TABLE payments (
  id               INT            NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  order_id         INT            NOT NULL,
  amount           DECIMAL(10, 2) NOT NULL,
  method           NVARCHAR(30)   NOT NULL CONSTRAINT ck_payments_method CHECK (
                     method IN ('credit_card', 'paypal', 'bank_transfer', 'crypto')
                   ),
  status           NVARCHAR(20)   NOT NULL CONSTRAINT ck_payments_status CHECK (
                     status IN ('pending', 'completed', 'failed', 'refunded')
                   ),
  transaction_ref  NVARCHAR(255)  NULL,
  created_at       DATETIME2      NOT NULL CONSTRAINT df_payments_created_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders (id)
);

-- ------------------------------------------------------------------
-- 011 — TAGS + PRODUCT_TAGS
-- ------------------------------------------------------------------
CREATE TABLE tags (
  id          INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name        NVARCHAR(50) NOT NULL UNIQUE,
  created_at  DATETIME2    NOT NULL CONSTRAINT df_tags_created_at DEFAULT SYSDATETIME()
);

CREATE TABLE product_tags (
  product_id  INT NOT NULL,
  tag_id      INT NOT NULL,
  CONSTRAINT pk_product_tags PRIMARY KEY (product_id, tag_id),
  CONSTRAINT fk_product_tags_product FOREIGN KEY (product_id) REFERENCES products (id),
  CONSTRAINT fk_product_tags_tag     FOREIGN KEY (tag_id)     REFERENCES tags (id)
);
