# Exercice 4 — Diagnostic de performance (le vrai problème)

> Cet exercice cible **SQL Server (T-SQL)**.

## Contexte

La requête suivante est utilisée par le dashboard "commandes du jour" de l'équipe ops.
Elle était rapide au lancement (quelques centaines de commandes),
mais elle prend maintenant plusieurs secondes en production.

```sql
SELECT
  u.username,
  u.email,
  o.id           AS order_id,
  o.status,
  o.total_amount,
  o.created_at,
  COUNT(oi.id)   AS item_count
FROM orders o
JOIN users u        ON u.id = o.customer_id
JOIN order_items oi ON oi.order_id = o.id
WHERE o.status IN ('pending', 'confirmed')
  AND o.created_at >= DATEADD(HOUR, -24, SYSDATETIME())
GROUP BY u.username, u.email, o.id, o.status, o.total_amount, o.created_at
ORDER BY o.created_at DESC;
```

---

## Travail demandé

### Étape 1 — Reproduire et mesurer

Activez les statistiques d'E/S et de temps, puis exécutez la requête. Demandez à
Claude d'interpréter le résultat. Activez aussi le plan d'exécution réel
(SSMS : « Include Actual Execution Plan » / Ctrl+M ; Azure Data Studio : bouton
« Explain » ; DBeaver : « Explain Execution Plan »).

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
  u.username,
  u.email,
  o.id           AS order_id,
  o.status,
  o.total_amount,
  o.created_at,
  COUNT(oi.id)   AS item_count
FROM orders o
JOIN users u        ON u.id = o.customer_id
JOIN order_items oi ON oi.order_id = o.id
WHERE o.status IN ('pending', 'confirmed')
  AND o.created_at >= DATEADD(HOUR, -24, SYSDATETIME())
GROUP BY u.username, u.email, o.id, o.status, o.total_amount, o.created_at
ORDER BY o.created_at DESC;
```

`STATISTICS IO` affiche le nombre de **logical reads** par table : c'est l'indicateur
clé pour mesurer le travail évité par un index.

### Étape 2 — Identifier le problème

Demandez à Claude :
> "Dans ce plan d'exécution, quels opérateurs sont les plus coûteux ?
>  Pourquoi observe-t-on un *Clustered Index Scan* sur orders malgré un filtre très sélectif ?"

Le plan révèle un **Clustered Index Scan** sur `orders` (SQL Server parcourt les 8000 lignes
de la clé primaire faute de mieux) : aucun index ne couvre `status` ni `created_at`,
donc le filtre `WHERE` ne peut pas être appliqué par un *seek*.

> Note importante : contrairement à MySQL/InnoDB, SQL Server **ne crée AUCUN index
> automatique sur les colonnes de clé étrangère** (`customer_id`, `order_id`, …).
> Seuls la clé primaire (index *clustered*) et les contraintes `UNIQUE` sont indexés.
> C'est le même comportement que PostgreSQL. Ici, le problème porte sur les colonnes
> de **filtre métier** (`status`, `created_at`), qui ne sont couvertes par rien —
> et selon les jointures, les FK non plus.

### Étape 3 — Corriger

Demandez à Claude de générer les instructions `CREATE INDEX` manquantes,
en justifiant chaque choix (colonne, ordre pour les index composites).

La solution attendue :

```sql
-- Filtre principal : status + plage de dates (index composite)
CREATE INDEX idx_orders_status_created ON orders (status, created_at DESC);

-- Filtre sur date seule (utile pour d'autres requêtes de reporting)
CREATE INDEX idx_orders_created_at ON orders (created_at DESC);

-- La jointure order_items.order_id n'est pas indexée non plus (pas d'auto-index FK)
CREATE INDEX idx_order_items_order ON order_items (order_id);
```

> Pour aller plus loin, demandez à Claude ce qu'apporterait un index **couvrant**
> avec `INCLUDE (total_amount)` pour éviter les *key lookups*.

### Étape 4 — Vérifier

Relancez la requête (avec `SET STATISTICS IO ON;` et le plan réel) après avoir créé
les index. Demandez à Claude de comparer les deux plans et de quantifier le gain
(baisse des *logical reads*, passage de *Scan* à *Seek*).

---

## Ce que vous devez observer

| Avant index | Après index |
|-------------|-------------|
| `Clustered Index Scan` sur `orders` (8000 lignes parcourues) | `Index Seek` sur `idx_orders_status_created` |
| `STATISTICS IO` élevé sur `orders` | `logical reads` nettement réduits sur `orders` |
| Filtre appliqué après lecture de toute la table | Filtre appliqué dès l'accès à l'index |

> Le jeu de données est petit (8000 commandes), donc le gain en millisecondes reste modeste :
> l'intérêt pédagogique est le **changement d'opérateur** (Scan → Seek), dont l'écart
> se creuse à mesure que la table grossit.

---

## Question bonus — SQL Server vs MySQL vs PostgreSQL

> "Les clés étrangères créent-elles automatiquement un index sur la colonne portante ?"

Réponse attendue :
- **MySQL / InnoDB** : oui, un index est créé automatiquement sur la colonne FK si aucun
  index existant ne la couvre déjà.
- **SQL Server** : non, aucun index implicite sur les FK. Seuls la PK (clustered) et les
  contraintes `UNIQUE` sont indexés.
- **PostgreSQL** : non plus. Comme SQL Server, le développeur doit créer les index de FK
  manuellement — source fréquente de jointures lentes.
