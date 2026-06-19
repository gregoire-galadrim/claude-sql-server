# Exercice 2 — Explication de requêtes

> Toutes les requêtes ciblent **PostgreSQL**.

Collez chaque requête dans Claude Code et demandez-lui :
> "Expliquez cette requête étape par étape, comme si je débutais en SQL."

Puis une deuxième fois :
> "Quels sont les risques ou limites de cette requête sur un gros volume de données ?"

---

## 2.1 — Requête avec window functions

```sql
SELECT
  u.username,
  o.created_at::DATE                                         AS order_date,
  o.total_amount,
  SUM(o.total_amount) OVER (
    PARTITION BY o.customer_id
    ORDER BY o.created_at
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  )                                                          AS cumulative_spend,
  RANK() OVER (
    PARTITION BY DATE_TRUNC('month', o.created_at)
    ORDER BY o.total_amount DESC
  )                                                          AS rank_in_month
FROM orders o
JOIN users u ON u.id = o.customer_id
WHERE o.status = 'delivered'
ORDER BY o.customer_id, o.created_at;
```

> `DATE_TRUNC('month', o.created_at)` remplace `DATEFROMPARTS(YEAR(...), MONTH(...), 1)`
> de SQL Server ou `DATETRUNC(MONTH, ...)` (SQL Server 2022+). C'est la façon idiomatique
> de tronquer à un mois en PostgreSQL.
>
> `o.created_at::DATE` est l'équivalent de `CAST(o.created_at AS DATE)` — les deux syntaxes
> sont acceptées en PostgreSQL.

---

## 2.2 — Requête récursive (catégories hiérarchiques)

```sql
WITH RECURSIVE category_tree AS (
  SELECT id, name, parent_id, 0 AS depth, name AS path
  FROM categories
  WHERE parent_id IS NULL

  UNION ALL

  SELECT c.id, c.name, c.parent_id, ct.depth + 1,
         ct.path || ' > ' || c.name
  FROM categories c
  JOIN category_tree ct ON ct.id = c.parent_id
)
SELECT path, depth
FROM category_tree
ORDER BY path;
```

> En PostgreSQL, le mot-clé `RECURSIVE` est **obligatoire** dans `WITH RECURSIVE` (contrairement
> à SQL Server où `WITH` suffit, la récursivité étant détectée par l'`UNION ALL`).
>
> Le `CAST(name AS NVARCHAR(1000))` de la version SQL Server n'est pas nécessaire ici :
> PostgreSQL résout la compatibilité de type automatiquement pour `TEXT` / `VARCHAR`.
> L'opérateur `||` concatène des chaînes.
>
> Il n'y a pas de limite de récursion par défaut en PostgreSQL (pas de `OPTION (MAXRECURSION 0)`).

---

## 2.3 — Sous-requête corrélée (intentionnellement lente)

```sql
SELECT
  p.id,
  p.name,
  p.price,
  (
    SELECT ROUND(AVG(r.rating::NUMERIC), 2)
    FROM reviews r
    WHERE r.product_id = p.id
  ) AS avg_rating,
  (
    SELECT COUNT(*)
    FROM order_items oi
    WHERE oi.product_id = p.id
  ) AS total_sold
FROM products p
WHERE p.is_active = TRUE
ORDER BY total_sold DESC
LIMIT 20;
```

> `LIMIT 20` remplace `TOP (20)`. `is_active = TRUE` (ou simplement `is_active`) remplace
> `is_active = 1` (le type `BIT` de SQL Server devient `BOOLEAN` en PostgreSQL).
>
> `AVG(r.rating)` sur un `SMALLINT` renvoie déjà un `NUMERIC` en PostgreSQL — pas de
> division entière. Le `::NUMERIC` explicite est conservé pour la clarté mais n'est pas
> strictement nécessaire ici.
>
> Après l'explication, demandez à Claude de réécrire cette requête sans sous-requête corrélée.

---

## 2.4 — Agrégation conditionnelle

```sql
SELECT
  u.username,
  COUNT(o.id)                                                   AS total_orders,
  COUNT(o.id) FILTER (WHERE o.status = 'delivered')             AS delivered,
  COUNT(o.id) FILTER (WHERE o.status = 'cancelled')             AS cancelled,
  COUNT(o.id) FILTER (WHERE o.status = 'refunded')              AS refunded,
  ROUND(
    COUNT(o.id) FILTER (WHERE o.status = 'cancelled') * 100.0
    / NULLIF(COUNT(o.id), 0),
    1
  )                                                             AS cancel_rate_pct
FROM users u
LEFT JOIN orders o ON o.customer_id = u.id
WHERE u.role = 'customer'
GROUP BY u.id, u.username
HAVING COUNT(o.id) > 0
ORDER BY cancel_rate_pct DESC NULLS LAST
LIMIT 15;
```

> Deux avantages PostgreSQL par rapport à SQL Server à expliquer :
>
> 1. **`FILTER (WHERE ...)`** — PostgreSQL supporte cette clause SQL standard pour
>    l'agrégation conditionnelle. Pas besoin du `SUM(CASE WHEN ... THEN 1 ELSE 0 END)`
>    de SQL Server. La requête est plus lisible et généralement plus rapide.
>
> 2. **`NULLS LAST`** — PostgreSQL supporte nativement `ORDER BY col DESC NULLS LAST`
>    (et `NULLS FIRST`). SQL Server l'émule via un `CASE` dans le `ORDER BY`.
>
> Le `* 100.0` reste nécessaire pour forcer un calcul en virgule flottante (sinon
> `integer / integer` donne une division entière même en PostgreSQL).
