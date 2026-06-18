# Exercice 2 — Explication de requêtes

> Toutes les requêtes ciblent **SQL Server (T-SQL)**.

Collez chaque requête dans Claude Code et demandez-lui :
> "Expliquez cette requête étape par étape, comme si je débutais en SQL."

Puis une deuxième fois :
> "Quels sont les risques ou limites de cette requête sur un gros volume de données ?"

---

## 2.1 — Requête avec window functions

```sql
SELECT
  u.username,
  CAST(o.created_at AS DATE)                                 AS order_date,
  o.total_amount,
  SUM(o.total_amount) OVER (
    PARTITION BY o.customer_id
    ORDER BY o.created_at
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  )                                                          AS cumulative_spend,
  RANK() OVER (
    PARTITION BY DATEFROMPARTS(YEAR(o.created_at), MONTH(o.created_at), 1)
    ORDER BY o.total_amount DESC
  )                                                          AS rank_in_month
FROM orders o
JOIN users u ON u.id = o.customer_id
WHERE o.status = 'delivered'
ORDER BY o.customer_id, o.created_at;
```

> `DATEFROMPARTS(YEAR(...), MONTH(...), 1)` remplace le `DATE_FORMAT(..., '%Y-%m-01')`
> de MySQL pour regrouper par mois. Sur SQL Server 2022+, `DATETRUNC(MONTH, o.created_at)`
> est une alternative équivalente.

---

## 2.2 — Requête récursive (catégories hiérarchiques)

```sql
WITH category_tree AS (
  SELECT id, name, parent_id, 0 AS depth, CAST(name AS NVARCHAR(1000)) AS path
  FROM categories
  WHERE parent_id IS NULL

  UNION ALL

  SELECT c.id, c.name, c.parent_id, ct.depth + 1,
         CAST(CONCAT(ct.path, ' > ', c.name) AS NVARCHAR(1000))
  FROM categories c
  JOIN category_tree ct ON ct.id = c.parent_id
)
SELECT path, depth
FROM category_tree
ORDER BY path;
```

> En T-SQL, le mot-clé `RECURSIVE` n'existe pas : `WITH` suffit, SQL Server détecte
> la récursivité via l'`UNION ALL` auto-référent. Par défaut la récursion est limitée
> à 100 niveaux ; au-delà, ajoutez `OPTION (MAXRECURSION 0)` en fin de requête.
> Notez aussi le `CAST(... AS NVARCHAR(1000))` dans le membre récursif : les deux
> branches de l'`UNION ALL` doivent avoir exactement le même type.

---

## 2.3 — Sous-requête corrélée (intentionnellement lente)

```sql
SELECT TOP (20)
  p.id,
  p.name,
  p.price,
  (
    SELECT ROUND(AVG(CAST(r.rating AS DECIMAL(4, 2))), 2)
    FROM reviews r
    WHERE r.product_id = p.id
  ) AS avg_rating,
  (
    SELECT COUNT(*)
    FROM order_items oi
    WHERE oi.product_id = p.id
  ) AS total_sold
FROM products p
WHERE p.is_active = 1
ORDER BY total_sold DESC;
```

> `TOP (20)` remplace `LIMIT 20`, `is_active = 1` remplace `= TRUE` (booléen = `BIT`).
> Le `CAST(r.rating AS DECIMAL(4,2))` évite une moyenne entière : `rating` est un `TINYINT`,
> et `AVG` sur un entier renvoie un entier en SQL Server.

> Après l'explication, demandez à Claude de réécrire cette requête sans sous-requête corrélée.

---

## 2.4 — Agrégation conditionnelle

```sql
SELECT TOP (15)
  u.username,
  COUNT(o.id)                                                AS total_orders,
  SUM(CASE WHEN o.status = 'delivered' THEN 1 ELSE 0 END)    AS delivered,
  SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END)    AS cancelled,
  SUM(CASE WHEN o.status = 'refunded'  THEN 1 ELSE 0 END)    AS refunded,
  ROUND(
    SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END) * 100.0
    / NULLIF(COUNT(o.id), 0),
    1
  )                                                          AS cancel_rate_pct
FROM users u
LEFT JOIN orders o ON o.customer_id = u.id
WHERE u.role = 'customer'
GROUP BY u.id, u.username
HAVING COUNT(o.id) > 0
ORDER BY
  CASE WHEN COUNT(o.id) = 0 THEN 1 ELSE 0 END,   -- NULLS LAST émulé
  cancel_rate_pct DESC;
```

> Deux pièges T-SQL à expliquer :
> 1. Le `* 100.0` (et non `* 100`) force un calcul en virgule flottante. Sans cela,
>    `SUM(...) / COUNT(...)` est une **division entière** qui renvoie 0.
> 2. SQL Server ne connaît ni `COUNT(...) FILTER (WHERE ...)` (PostgreSQL) ni `NULLS LAST`.
>    On utilise `CASE WHEN ... THEN 1 ELSE 0 END` pour l'agrégation conditionnelle,
>    et un `CASE` dans le `ORDER BY` pour rejeter les valeurs nulles en fin de tri.
