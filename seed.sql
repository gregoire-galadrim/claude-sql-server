-- =============================================================
-- SEED — marketplace e-commerce (SQL Server / T-SQL)
-- Volume cible : ~500 users, ~2000 products, ~8000 orders,
--                ~24000 order_items, ~4000 reviews
-- Compatible SQL Server 2019+ (testé sur SQL Server 2022)
-- =============================================================
--
-- Différences clés avec la version MySQL :
--  * RAND() est un CONSTANT D'EXÉCUTION en SQL Server : il est évalué une seule
--    fois par requête. Pour obtenir une valeur différente PAR LIGNE on utilise
--    RAND(CHECKSUM(NEWID())) — NEWID() étant ré-évalué pour chaque ligne.
--  * ELT() -> CHOOSE(), LPAD() -> RIGHT(...), MD5() -> HASHBYTES('MD5', ...).
--  * INSERT IGNORE n'existe pas : on dédoublonne en amont avec ROW_NUMBER().
--  * generate_series / CTE récursive -> table de tally #seq via ROW_NUMBER().
-- =============================================================

SET NOCOUNT ON;

BEGIN TRANSACTION;

-- ------------------------------------------------------------------
-- TABLE DE SÉQUENCES (remplace generate_series / la CTE récursive)
-- 30000 entiers générés par produit cartésien sur sys.all_objects.
-- ------------------------------------------------------------------
CREATE TABLE #seq (n INT NOT NULL PRIMARY KEY);

INSERT INTO #seq (n)
SELECT TOP (30000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

-- ------------------------------------------------------------------
-- USERS
-- 50 admins (ids 1-50), 150 sellers (ids 51-200), 300 customers (ids 201-500)
-- ------------------------------------------------------------------
INSERT INTO users (email, username, full_name, role, created_at)
SELECT
  CONCAT('admin', n, '@marketplace.dev'),
  CONCAT('admin_', n),
  CONCAT('Admin User ', n),
  'admin',
  DATEADD(DAY, -CAST(FLOOR(RAND(CHECKSUM(NEWID())) * 730) AS INT), SYSDATETIME())
FROM #seq WHERE n <= 50;

INSERT INTO users (email, username, full_name, role, created_at)
SELECT
  CONCAT('seller', n, '@marketplace.dev'),
  CONCAT('seller_', n),
  CONCAT('Seller ', n),
  'seller',
  DATEADD(DAY, -CAST(FLOOR(RAND(CHECKSUM(NEWID())) * 730) AS INT), SYSDATETIME())
FROM #seq WHERE n <= 150;

INSERT INTO users (email, username, full_name, role, created_at)
SELECT
  CONCAT('customer', n, '@example.com'),
  CONCAT('customer_', n),
  CONCAT('Customer ', n),
  'customer',
  DATEADD(DAY, -CAST(FLOOR(RAND(CHECKSUM(NEWID())) * 730) AS INT), SYSDATETIME())
FROM #seq WHERE n <= 300;

-- ------------------------------------------------------------------
-- CATEGORIES (3 niveaux : 6 racines, 15 sous-catégories, 6 feuilles)
-- ------------------------------------------------------------------
INSERT INTO categories (name, slug, parent_id) VALUES
  (N'Électronique',        'electronique',          NULL),
  (N'Vêtements',           'vetements',             NULL),
  (N'Maison & Jardin',     'maison-jardin',         NULL),
  (N'Sports & Loisirs',    'sports-loisirs',        NULL),
  (N'Livres & Médias',     'livres-medias',         NULL),
  (N'Alimentation',        'alimentation',          NULL);

INSERT INTO categories (name, slug, parent_id) VALUES
  (N'Smartphones',         'smartphones',           1),
  (N'Ordinateurs',         'ordinateurs',           1),
  (N'Audio',               'audio',                 1),
  (N'Homme',               'vetements-homme',       2),
  (N'Femme',               'vetements-femme',       2),
  (N'Enfant',              'vetements-enfant',      2),
  (N'Meubles',             'meubles',               3),
  (N'Décoration',          'decoration',            3),
  (N'Jardinage',           'jardinage',             3),
  (N'Fitness',             'fitness',               4),
  (N'Plein air',           'plein-air',             4),
  (N'Romans',              'romans',                5),
  (N'Technique',           'technique',             5),
  (N'Bio & Vrac',          'bio-vrac',              6),
  (N'Épicerie fine',       'epicerie-fine',         6);

INSERT INTO categories (name, slug, parent_id) VALUES
  (N'iPhone',              'iphone',                7),
  (N'Android',             'android',               7),
  (N'Laptops',             'laptops',               8),
  (N'Desktops',            'desktops',              8),
  (N'Casques',             'casques',               9),
  (N'Enceintes',           'enceintes',             9);

-- ------------------------------------------------------------------
-- PRODUCTS (2000 produits répartis sur les sellers)
-- ------------------------------------------------------------------
INSERT INTO products (seller_id, category_id, name, description, price, is_active, created_at)
SELECT
  CAST(FLOOR(51 + RAND(CHECKSUM(NEWID())) * 150) AS INT),
  CAST(FLOOR(7  + RAND(CHECKSUM(NEWID())) * 15) AS INT),
  CONCAT('Produit ', n, ' - ', LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', CAST(n AS VARCHAR(20))), 2))),
  CONCAT(N'Description détaillée du produit numéro ', n, N'. Qualité garantie.'),
  CAST(ROUND(RAND(CHECKSUM(NEWID())) * 490 + 10, 2) AS DECIMAL(10, 2)),
  CASE WHEN RAND(CHECKSUM(NEWID())) > 0.1 THEN 1 ELSE 0 END,
  DATEADD(DAY, -CAST(FLOOR(RAND(CHECKSUM(NEWID())) * 540) AS INT), SYSDATETIME())
FROM #seq WHERE n <= 2000;

-- ------------------------------------------------------------------
-- ADDRESSES (2 par customer en moyenne)
-- NOTE : l'index de CHOOSE est matérialisé dans une table intermédiaire.
-- Une expression non déterministe (NEWID()) passée directement à CHOOSE est
-- ré-évaluée à chaque branche interne et peut ne matcher aucune valeur -> NULL.
-- ------------------------------------------------------------------
SELECT
  n,
  201 + ((n - 1) / 2)              AS user_id,
  ABS(CHECKSUM(NEWID())) % 8 + 1   AS city_idx,
  ABS(CHECKSUM(NEWID())) % 90000 + 10000 AS postal
INTO #addr_rnd
FROM #seq WHERE n <= 600;

INSERT INTO addresses (user_id, street, city, postal_code, country, is_default)
SELECT
  user_id,
  CONCAT(n * 7, ' Rue de la Paix'),
  CHOOSE(city_idx, 'Paris', 'Lyon', 'Marseille', 'Bordeaux', 'Lille', 'Nantes', 'Toulouse', 'Strasbourg'),
  RIGHT('00000' + CAST(postal AS VARCHAR(5)), 5),
  'France',
  CAST(n % 2 AS BIT)
FROM #addr_rnd;

DROP TABLE #addr_rnd;

-- ------------------------------------------------------------------
-- ORDERS (8000 commandes sur les customers)
-- ------------------------------------------------------------------
SELECT
  CAST(FLOOR(201 + RAND(CHECKSUM(NEWID())) * 300) AS INT) AS customer_id,
  CAST(FLOOR(1   + RAND(CHECKSUM(NEWID())) * 600) AS INT) AS shipping_address_id,
  ABS(CHECKSUM(NEWID())) % 8 + 1                          AS status_idx,
  CAST(FLOOR(RAND(CHECKSUM(NEWID())) * 365) AS INT)       AS created_off,
  CAST(FLOOR(RAND(CHECKSUM(NEWID())) * 182) AS INT)       AS updated_off
INTO #ord_rnd
FROM #seq WHERE n <= 8000;

INSERT INTO orders (customer_id, shipping_address_id, status, total_amount, created_at, updated_at)
SELECT
  customer_id,
  shipping_address_id,
  CHOOSE(status_idx, 'pending', 'confirmed', 'shipped', 'delivered', 'delivered', 'delivered', 'cancelled', 'refunded'),
  0,
  DATEADD(DAY, -created_off, SYSDATETIME()),
  DATEADD(DAY, -updated_off, SYSDATETIME())
FROM #ord_rnd;

DROP TABLE #ord_rnd;

-- ------------------------------------------------------------------
-- ORDER ITEMS (~3 lignes par commande -> 24000 lignes)
-- ------------------------------------------------------------------
INSERT INTO order_items (order_id, product_id, quantity, unit_price, created_at)
SELECT
  CAST(FLOOR(1 + RAND(CHECKSUM(NEWID())) * 8000) AS INT),
  CAST(FLOOR(1 + RAND(CHECKSUM(NEWID())) * 2000) AS INT),
  CAST(FLOOR(1 + RAND(CHECKSUM(NEWID())) * 5) AS INT),
  CAST(ROUND(RAND(CHECKSUM(NEWID())) * 490 + 10, 2) AS DECIMAL(10, 2)),
  DATEADD(DAY, -CAST(FLOOR(RAND(CHECKSUM(NEWID())) * 365) AS INT), SYSDATETIME())
FROM #seq WHERE n <= 24000;

-- Recalcul du total des commandes (syntaxe SQL Server : UPDATE ... FROM ... JOIN)
UPDATE o
SET o.total_amount = sub.total
FROM orders o
JOIN (
  SELECT order_id, SUM(quantity * unit_price) AS total
  FROM order_items
  GROUP BY order_id
) sub ON sub.order_id = o.id;

-- ------------------------------------------------------------------
-- REVIEWS (~4000 avis — dédoublonnage product+customer via ROW_NUMBER,
-- équivalent du INSERT IGNORE de MySQL)
-- ------------------------------------------------------------------
SELECT
  CAST(FLOOR(1   + RAND(CHECKSUM(NEWID())) * 2000) AS INT) AS product_id,
  CAST(FLOOR(201 + RAND(CHECKSUM(NEWID())) * 300) AS INT) AS customer_id,
  CAST(FLOOR(1   + RAND(CHECKSUM(NEWID())) * 5) AS TINYINT) AS rating,
  CASE WHEN RAND(CHECKSUM(NEWID())) > 0.3
    THEN CONCAT(N'Très bon produit, je recommande. Note : ', CAST(FLOOR(1 + RAND(CHECKSUM(NEWID())) * 5) AS INT))
    ELSE NULL
  END AS content,
  DATEADD(DAY, -CAST(FLOOR(RAND(CHECKSUM(NEWID())) * 300) AS INT), SYSDATETIME()) AS created_at
INTO #review_cand
FROM #seq WHERE n <= 5000;

INSERT INTO reviews (product_id, customer_id, rating, content, created_at)
SELECT product_id, customer_id, rating, content, created_at
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY product_id, customer_id ORDER BY (SELECT NULL)) AS rn
  FROM #review_cand
) d
WHERE rn = 1;

DROP TABLE #review_cand;

-- ------------------------------------------------------------------
-- INVENTORY (1 entrée par produit)
-- ------------------------------------------------------------------
INSERT INTO inventory (product_id, quantity, reorder_threshold)
SELECT
  id,
  CAST(FLOOR(RAND(CHECKSUM(NEWID())) * 500) AS INT),
  5 + CAST(FLOOR(RAND(CHECKSUM(NEWID())) * 45) AS INT)
FROM products;

-- ------------------------------------------------------------------
-- PAYMENTS (1 paiement par commande)
-- ------------------------------------------------------------------
SELECT
  id,
  total_amount,
  status,
  created_at,
  ABS(CHECKSUM(NEWID())) % 5 + 1 AS method_idx
INTO #pay_rnd
FROM orders;

INSERT INTO payments (order_id, amount, method, status, transaction_ref, created_at)
SELECT
  id,
  total_amount,
  CHOOSE(method_idx, 'credit_card', 'credit_card', 'paypal', 'bank_transfer', 'crypto'),
  CASE status
    WHEN 'delivered' THEN 'completed'
    WHEN 'shipped'   THEN 'completed'
    WHEN 'confirmed' THEN 'completed'
    WHEN 'refunded'  THEN 'refunded'
    WHEN 'cancelled' THEN 'failed'
    ELSE 'pending'
  END,
  UPPER(CONVERT(VARCHAR(32), HASHBYTES('MD5', CAST(NEWID() AS VARCHAR(36))), 2)),
  DATEADD(HOUR, 1, created_at)
FROM #pay_rnd;

DROP TABLE #pay_rnd;

-- ------------------------------------------------------------------
-- TAGS + PRODUCT_TAGS
-- ------------------------------------------------------------------
INSERT INTO tags (name) VALUES
  (N'promo'), (N'nouveau'), (N'bestseller'), (N'bio'), (N'reconditionné'),
  (N'édition-limitée'), (N'made-in-france'), (N'livraison-rapide'),
  (N'premium'), (N'éco-responsable'), (N'exclusif'), (N'soldes');

-- Dédoublonnage (product_id, tag_id) — équivalent du INSERT IGNORE
SELECT
  CAST(FLOOR(1 + RAND(CHECKSUM(NEWID())) * 2000) AS INT) AS product_id,
  CAST(FLOOR(1 + RAND(CHECKSUM(NEWID())) * 12) AS INT) AS tag_id
INTO #product_tags_cand
FROM #seq WHERE n <= 6000;

INSERT INTO product_tags (product_id, tag_id)
SELECT product_id, tag_id
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY product_id, tag_id ORDER BY (SELECT NULL)) AS rn
  FROM #product_tags_cand
) d
WHERE rn = 1;

DROP TABLE #product_tags_cand;

DROP TABLE #seq;

COMMIT;
