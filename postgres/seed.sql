-- =============================================================
-- SEED — marketplace e-commerce (PostgreSQL)
-- Volume cible : ~500 users, ~2000 products, ~8000 orders,
--                ~24000 order_items, ~4000 reviews
-- Compatible PostgreSQL 14+
-- =============================================================
--
-- Différences clés avec la version SQL Server :
--  * generate_series(1, n) remplace la table de tally #seq.
--  * random() est réévalué par ligne dans les requêtes ensemblistes,
--    contrairement à RAND() de SQL Server qui est constant par requête
--    (d'où le RAND(CHECKSUM(NEWID())) dans la version T-SQL).
--  * (ARRAY[...])[i] remplace CHOOSE(i, ...) — les tableaux PostgreSQL sont
--    indexés à partir de 1, comme CHOOSE.
--  * md5(text) remplace HASHBYTES('MD5', ...) + CONVERT(..., 2).
--  * gen_random_uuid() (pgcrypto) remplace NEWID().
--  * lpad(text, n, '0') remplace RIGHT('00000' + ...).
--  * ON CONFLICT DO NOTHING remplace le dédoublonnage via ROW_NUMBER().
--  * UPDATE ... FROM (subquery) AS sub WHERE sub.id = t.id — même syntaxe
--    que SQL Server pour le UPDATE avec jointure.
-- =============================================================

BEGIN;

-- ------------------------------------------------------------------
-- USERS
-- 50 admins (ids 1-50), 150 sellers (ids 51-200), 300 customers (ids 201-500)
-- ------------------------------------------------------------------
INSERT INTO users (email, username, full_name, role, created_at)
SELECT
  'admin' || n || '@marketplace.dev',
  'admin_' || n,
  'Admin User ' || n,
  'admin',
  NOW() - (floor(random() * 730)::int || ' days')::interval
FROM generate_series(1, 50) AS s(n);

INSERT INTO users (email, username, full_name, role, created_at)
SELECT
  'seller' || n || '@marketplace.dev',
  'seller_' || n,
  'Seller ' || n,
  'seller',
  NOW() - (floor(random() * 730)::int || ' days')::interval
FROM generate_series(1, 150) AS s(n);

INSERT INTO users (email, username, full_name, role, created_at)
SELECT
  'customer' || n || '@example.com',
  'customer_' || n,
  'Customer ' || n,
  'customer',
  NOW() - (floor(random() * 730)::int || ' days')::interval
FROM generate_series(1, 300) AS s(n);

-- ------------------------------------------------------------------
-- CATEGORIES (3 niveaux : 6 racines, 15 sous-catégories, 6 feuilles)
-- ------------------------------------------------------------------
INSERT INTO categories (name, slug, parent_id) VALUES
  ('Électronique',        'electronique',          NULL),
  ('Vêtements',           'vetements',             NULL),
  ('Maison & Jardin',     'maison-jardin',         NULL),
  ('Sports & Loisirs',    'sports-loisirs',        NULL),
  ('Livres & Médias',     'livres-medias',         NULL),
  ('Alimentation',        'alimentation',          NULL);

INSERT INTO categories (name, slug, parent_id) VALUES
  ('Smartphones',         'smartphones',           1),
  ('Ordinateurs',         'ordinateurs',           1),
  ('Audio',               'audio',                 1),
  ('Homme',               'vetements-homme',       2),
  ('Femme',               'vetements-femme',       2),
  ('Enfant',              'vetements-enfant',      2),
  ('Meubles',             'meubles',               3),
  ('Décoration',          'decoration',            3),
  ('Jardinage',           'jardinage',             3),
  ('Fitness',             'fitness',               4),
  ('Plein air',           'plein-air',             4),
  ('Romans',              'romans',                5),
  ('Technique',           'technique',             5),
  ('Bio & Vrac',          'bio-vrac',              6),
  ('Épicerie fine',       'epicerie-fine',         6);

INSERT INTO categories (name, slug, parent_id) VALUES
  ('iPhone',              'iphone',                7),
  ('Android',             'android',               7),
  ('Laptops',             'laptops',               8),
  ('Desktops',            'desktops',              8),
  ('Casques',             'casques',               9),
  ('Enceintes',           'enceintes',             9);

-- ------------------------------------------------------------------
-- PRODUCTS (2000 produits répartis sur les sellers)
-- ------------------------------------------------------------------
INSERT INTO products (seller_id, category_id, name, description, price, is_active, created_at)
SELECT
  (floor(51 + random() * 150))::int,
  (floor(7  + random() * 15))::int,
  'Produit ' || n || ' - ' || md5(n::text),
  'Description détaillée du produit numéro ' || n || '. Qualité garantie.',
  round((random() * 490 + 10)::numeric, 2),
  random() > 0.1,
  NOW() - (floor(random() * 540)::int || ' days')::interval
FROM generate_series(1, 2000) AS s(n);

-- ------------------------------------------------------------------
-- ADDRESSES (2 par customer en moyenne, 600 adresses pour 300 customers)
-- ------------------------------------------------------------------
INSERT INTO addresses (user_id, street, city, postal_code, country, is_default)
SELECT
  201 + ((n - 1) / 2),
  (n * 7) || ' Rue de la Paix',
  (ARRAY['Paris', 'Lyon', 'Marseille', 'Bordeaux', 'Lille', 'Nantes', 'Toulouse', 'Strasbourg'])[floor(random() * 8)::int + 1],
  lpad((floor(random() * 90000 + 10000)::int)::text, 5, '0'),
  'France',
  (n % 2 = 1)
FROM generate_series(1, 600) AS s(n);

-- ------------------------------------------------------------------
-- ORDERS (8000 commandes sur les customers)
-- ------------------------------------------------------------------
INSERT INTO orders (customer_id, shipping_address_id, status, total_amount, created_at, updated_at)
SELECT
  (floor(201 + random() * 300))::int,
  (floor(1   + random() * 600))::int,
  (ARRAY['pending', 'confirmed', 'shipped', 'delivered', 'delivered', 'delivered', 'cancelled', 'refunded'])[floor(random() * 8)::int + 1],
  0,
  NOW() - (floor(random() * 365)::int || ' days')::interval,
  NOW() - (floor(random() * 182)::int || ' days')::interval
FROM generate_series(1, 8000);

-- ------------------------------------------------------------------
-- ORDER ITEMS (~3 lignes par commande -> 24000 lignes)
-- ------------------------------------------------------------------
INSERT INTO order_items (order_id, product_id, quantity, unit_price, created_at)
SELECT
  (floor(1 + random() * 8000))::int,
  (floor(1 + random() * 2000))::int,
  (floor(1 + random() * 5))::int,
  round((random() * 490 + 10)::numeric, 2),
  NOW() - (floor(random() * 365)::int || ' days')::interval
FROM generate_series(1, 24000);

-- Recalcul du total des commandes
UPDATE orders o
SET total_amount = sub.total
FROM (
  SELECT order_id, SUM(quantity * unit_price) AS total
  FROM order_items
  GROUP BY order_id
) sub
WHERE sub.order_id = o.id;

-- ------------------------------------------------------------------
-- REVIEWS (~4000 avis — dédoublonnage product+customer via ON CONFLICT)
-- ------------------------------------------------------------------
INSERT INTO reviews (product_id, customer_id, rating, content, created_at)
SELECT
  (floor(1   + random() * 2000))::int,
  (floor(201 + random() * 300))::int,
  (floor(1   + random() * 5))::int,
  CASE WHEN random() > 0.3
    THEN 'Très bon produit, je recommande. Note : ' || (floor(1 + random() * 5))::int
    ELSE NULL
  END,
  NOW() - (floor(random() * 300)::int || ' days')::interval
FROM generate_series(1, 5000)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------------
-- INVENTORY (1 entrée par produit)
-- ------------------------------------------------------------------
INSERT INTO inventory (product_id, quantity, reorder_threshold)
SELECT
  id,
  floor(random() * 500)::int,
  5 + floor(random() * 45)::int
FROM products;

-- ------------------------------------------------------------------
-- PAYMENTS (1 paiement par commande)
-- ------------------------------------------------------------------
INSERT INTO payments (order_id, amount, method, status, transaction_ref, created_at)
SELECT
  id,
  total_amount,
  (ARRAY['credit_card', 'credit_card', 'paypal', 'bank_transfer', 'crypto'])[floor(random() * 5)::int + 1],
  CASE status
    WHEN 'delivered' THEN 'completed'
    WHEN 'shipped'   THEN 'completed'
    WHEN 'confirmed' THEN 'completed'
    WHEN 'refunded'  THEN 'refunded'
    WHEN 'cancelled' THEN 'failed'
    ELSE 'pending'
  END,
  upper(md5(gen_random_uuid()::text)),
  created_at + INTERVAL '1 hour'
FROM orders;

-- ------------------------------------------------------------------
-- TAGS + PRODUCT_TAGS
-- ------------------------------------------------------------------
INSERT INTO tags (name) VALUES
  ('promo'), ('nouveau'), ('bestseller'), ('bio'), ('reconditionné'),
  ('édition-limitée'), ('made-in-france'), ('livraison-rapide'),
  ('premium'), ('éco-responsable'), ('exclusif'), ('soldes');

INSERT INTO product_tags (product_id, tag_id)
SELECT
  (floor(1 + random() * 2000))::int,
  (floor(1 + random() * 12))::int
FROM generate_series(1, 6000)
ON CONFLICT DO NOTHING;

COMMIT;
