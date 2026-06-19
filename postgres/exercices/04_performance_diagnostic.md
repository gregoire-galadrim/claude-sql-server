# Exercice 4 — Diagnostic de performance (le vrai problème)

> Cet exercice cible **PostgreSQL**.

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
  AND o.created_at >= NOW() - INTERVAL '24 hours'
GROUP BY u.username, u.email, o.id, o.status, o.total_amount, o.created_at
ORDER BY o.created_at DESC;
```

---

## Travail demandé

### Étape 1 — Reproduire et mesurer

Activez l'analyse du plan d'exécution, puis exécutez la requête :

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
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
  AND o.created_at >= NOW() - INTERVAL '24 hours'
GROUP BY u.username, u.email, o.id, o.status, o.total_amount, o.created_at
ORDER BY o.created_at DESC;
```

> `EXPLAIN (ANALYZE, BUFFERS)` est l'équivalent PostgreSQL de
> `SET STATISTICS IO, TIME ON` + plan d'exécution réel de SQL Server / SSMS.
> `Buffers` indique le nombre de blocs de 8 Ko lus (shared hit + read) —
> c'est l'indicateur clé pour mesurer le travail évité par un index
> (équivalent des *logical reads* de SQL Server).

Demandez à Claude d'interpréter le résultat. Vous pouvez aussi utiliser l'interface
graphique de pgAdmin (F7) ou DBeaver (Ctrl+Shift+E) pour visualiser le plan.

### Étape 2 — Identifier le problème

Demandez à Claude :
> "Dans ce plan d'exécution, quels nœuds sont les plus coûteux ?
>  Pourquoi observe-t-on un *Seq Scan* sur orders malgré un filtre très sélectif ?"

Le plan révèle un **Seq Scan** sur `orders` (PostgreSQL parcourt les 8000 lignes
faute d'index utilisable) : aucun index ne couvre `status` ni `created_at`,
donc le filtre `WHERE` ne peut pas être appliqué par un *Index Scan*.

> Note importante : comme SQL Server, PostgreSQL **ne crée AUCUN index automatique
> sur les colonnes de clé étrangère** (`customer_id`, `order_id`, …).
> Seuls la clé primaire (index *btree* unique) et les contraintes `UNIQUE` sont indexés.
> C'est l'inverse de MySQL/InnoDB, qui indexe automatiquement chaque colonne FK.
> Ici, le problème porte sur les colonnes de **filtre métier** (`status`, `created_at`),
> qui ne sont couvertes par rien — et selon les jointures, les FK non plus.

### Étape 3 — Corriger

Demandez à Claude de générer les instructions `CREATE INDEX` manquantes,
en justifiant chaque choix (colonne, ordre pour les index composites).

La solution attendue :

```sql
-- Filtre principal : status + plage de dates (index composite)
CREATE INDEX idx_orders_status_created ON orders (status, created_at DESC);

-- Filtre sur date seule (utile pour d'autres requêtes de reporting)
CREATE INDEX idx_orders_created_at ON orders (created_at DESC);

-- La jointure order_items.order_id n'est pas indexée (pas d'auto-index FK)
CREATE INDEX idx_order_items_order ON order_items (order_id);
```

> Pour aller plus loin, demandez à Claude ce qu'apporterait un **index couvrant**
> avec `INCLUDE (total_amount)` (syntaxe disponible depuis PostgreSQL 11) pour
> éviter les *heap fetches* (équivalent des *key lookups* de SQL Server).

### Étape 4 — Vérifier

Relancez la requête avec `EXPLAIN (ANALYZE, BUFFERS)` après avoir créé les index.
Demandez à Claude de comparer les deux plans et de quantifier le gain
(baisse des *Buffers*, passage de *Seq Scan* à *Index Scan* ou *Bitmap Index Scan*).

---

## Ce que vous devez observer

| Avant index | Après index |
|-------------|-------------|
| `Seq Scan` sur `orders` (8000 lignes parcourues) | `Index Scan` sur `idx_orders_status_created` |
| `Buffers` élevés sur `orders` | `Buffers` nettement réduits sur `orders` |
| Filtre appliqué après lecture de toute la table | Filtre appliqué dès l'accès à l'index |

> Le jeu de données est petit (8000 commandes), donc le gain en millisecondes reste modeste :
> l'intérêt pédagogique est le **changement de nœud** (Seq Scan → Index Scan), dont l'écart
> se creuse à mesure que la table grossit.

---

## Question bonus — PostgreSQL vs MySQL vs SQL Server

> "Les clés étrangères créent-elles automatiquement un index sur la colonne portante ?"

Réponse attendue :
- **MySQL / InnoDB** : oui, un index est créé automatiquement sur la colonne FK si aucun
  index existant ne la couvre déjà.
- **PostgreSQL** : non. Le développeur doit créer les index de FK manuellement —
  source fréquente de jointures lentes sur les grosses tables.
- **SQL Server** : non plus. Même comportement que PostgreSQL.
