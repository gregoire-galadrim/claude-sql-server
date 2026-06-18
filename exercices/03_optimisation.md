# Exercice 3 — Optimisation de requêtes

> Toutes les requêtes ciblent **SQL Server (T-SQL)**.

Pour chaque requête, demandez à Claude Code :
> "Cette requête est lente. Proposez une version optimisée et expliquez chaque changement."

---

## 3.1 — Réécriture de sous-requête corrélée

La requête de l'exercice 2.3 (voir `02_explication.md`) exécute une sous-requête
pour **chaque ligne** de `products`. Sur 2000 produits, c'est 4000 allers-retours.

Objectif : réécrire avec des JOINs et GROUP BY.

---

## 3.2 — Mauvais usage de DISTINCT

```sql
SELECT DISTINCT u.username, u.email
FROM users u
JOIN orders o       ON o.customer_id = u.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p     ON p.id = oi.product_id
JOIN categories c   ON c.id = p.category_id
JOIN categories root ON root.id = COALESCE(c.parent_id, c.id)
WHERE root.parent_id IS NULL
  AND o.status = 'delivered'
  AND o.created_at >= DATEADD(MONTH, -3, SYSDATETIME());
```

Problème : le `DISTINCT` masque un produit cartésien.
Un même client a plusieurs commandes, chacune plusieurs `order_items` : la ligne
`(username, email)` est dupliquée des dizaines de fois avant le `DISTINCT`.
Objectif : identifier pourquoi des doublons apparaissent et réécrire proprement
(indice : `EXISTS` ou agrégation).

> Note sur les données : les produits sont rattachés à des **sous-catégories**
> (niveau 2). La jointure `root` remonte à la catégorie racine via `parent_id`
> pour que le filtre `root.parent_id IS NULL` renvoie bien des lignes.

---

## 3.3 — Calcul répété en ORDER BY

```sql
SELECT
  p.id,
  p.name,
  (SELECT COUNT(*) FROM order_items oi WHERE oi.product_id = p.id)             AS sales_count,
  (SELECT COALESCE(AVG(CAST(r.rating AS DECIMAL(4, 2))), 0)
     FROM reviews r WHERE r.product_id = p.id)                                 AS avg_rating
FROM products p
ORDER BY
  (SELECT COUNT(*) FROM order_items oi WHERE oi.product_id = p.id) DESC,
  (SELECT COALESCE(AVG(CAST(r.rating AS DECIMAL(4, 2))), 0)
     FROM reviews r WHERE r.product_id = p.id) DESC;
```

Problème : les sous-requêtes sont exécutées deux fois (SELECT + ORDER BY).
Objectif : utiliser une CTE ou une sous-requête englobante pour ne calculer qu'une fois.

---

## 3.4 — Agrégation sur une grande fenêtre temporelle

```sql
SELECT
  CAST(o.created_at AS DATE)       AS day,
  SUM(oi.quantity * oi.unit_price) AS daily_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.created_at >= '2020-01-01'
GROUP BY CAST(o.created_at AS DATE)
ORDER BY day;
```

Demandez à Claude :
1. D'analyser le plan d'exécution réel (activez « Include Actual Execution Plan » / Ctrl+M
   dans SSMS, ou `SET STATISTICS IO, TIME ON;` avant la requête).
2. De proposer un index adapté sur `orders (created_at)` et `order_items (order_id)`.
3. D'expliquer pourquoi `CAST(o.created_at AS DATE)` dans le `GROUP BY` empêche
   l'utilisation directe d'un index sur `created_at` (la colonne est « enveloppée »
   dans une fonction → non SARGable), et comment contourner ça en SQL Server :
   soit une **colonne calculée persistée** indexée
   (`ALTER TABLE orders ADD created_date AS CAST(created_at AS DATE) PERSISTED;`
   puis un index dessus), soit en filtrant par plages de bornes (`>= @jour AND < @jour+1`).
