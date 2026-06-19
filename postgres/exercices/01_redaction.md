# Exercice 1 — Rédaction de requêtes SQL

> Toutes les requêtes ciblent **PostgreSQL**. La base se crée avec
> `migration.sql` puis se remplit avec `seed.sql` (voir `docker-compose.yml` dans ce dossier).

Demandez à Claude Code de vous aider à rédiger les requêtes ci-dessous.
Pour chaque question, demandez-lui aussi d'expliquer ses choix (JOIN vs sous-requête, etc.).

---

## 1.1 — Classement des vendeurs

Retournez le top 10 des vendeurs par chiffre d'affaires total,
uniquement sur les commandes avec le statut `delivered`.
Inclure : nom du vendeur, nombre de produits distincts vendus, CA total.

---

## 1.2 — Clients inactifs

Listez les clients qui ont créé un compte il y a plus de 6 mois
mais qui n'ont **jamais** passé de commande.
Retourner : username, email, date de création du compte.

> En PostgreSQL : `NOW() - INTERVAL '6 months'` remplace `DATEADD(MONTH, -6, SYSDATETIME())`.

---

## 1.3 — Produits en rupture imminente

Affichez les produits dont le stock en `inventory` est inférieur ou égal
au seuil `reorder_threshold`, en incluant :
- nom du produit
- catégorie (nom)
- vendeur (username)
- quantité actuelle
- seuil

Triez par `(quantité / seuil)` croissant pour prioriser les plus urgents.

---

## 1.4 — Rapport mensuel par catégorie

Pour chaque **catégorie racine** (sans parent), calculez par mois
sur les 6 derniers mois :
- nombre de commandes contenant au moins un produit de cette catégorie
- revenu total généré
- note moyenne des produits de la catégorie

Utilisez une CTE pour structurer la requête.

> En PostgreSQL : `DATE_TRUNC('month', created_at)` pour tronquer au mois.

---

## 1.5 — Clients multi-achats fidèles

Trouvez les clients ayant :
- au moins 3 commandes `delivered`
- une note moyenne laissée dans `reviews` >= 4
- au moins un achat dans 2 catégories racines différentes

Retourner : username, nombre de commandes, note moyenne, liste des catégories racines (agrégée).

---

## 1.6 — CA et panier moyen par mode de paiement

Pour chaque mode de paiement (`payments.method`), en ne considérant que les paiements
au statut `completed`, calculez :
- le nombre de paiements
- le montant total encaissé
- le panier moyen (montant moyen par paiement)

Triez par montant total décroissant.

> Notez que `AVG` sur un `NUMERIC` en PostgreSQL renvoie directement un `NUMERIC` —
> pas de division entière à craindre. Mais gardez `ROUND(..., 2)` pour l'affichage.

---

## 1.7 — Produits jamais évalués

Listez les produits **actifs** (`is_active = TRUE`) qui n'ont reçu **aucun avis**
(aucune ligne dans `reviews`), alors qu'ils sont en stock (`inventory.quantity` strictement positif).
Retourner : nom du produit, vendeur (username), quantité en stock.

Demandez à Claude de comparer deux écritures : `NOT EXISTS` vs `LEFT JOIN ... WHERE ... IS NULL`,
et laquelle il privilégie ici.

---

## 1.8 — Nombre de produits par catégorie racine (arborescence incluse)

Pour chaque **catégorie racine** (sans parent), comptez le nombre total de produits
rattachés à elle **ou à l'une de ses sous-catégories** (sur les 3 niveaux de la hiérarchie).
Utilisez une **CTE récursive** (`WITH RECURSIVE`) pour parcourir l'arborescence.

Retourner : nom de la catégorie racine, nombre total de produits. Triez par total décroissant.

> En PostgreSQL, le mot-clé `RECURSIVE` est obligatoire (contrairement à SQL Server où `WITH`
> suffit). Il n'y a pas de limite de récursion par défaut (pas besoin de l'équivalent de
> `OPTION (MAXRECURSION 0)`).

---

## 1.9 — Top 3 des produits par catégorie

Pour chaque catégorie, retournez les **3 produits les plus vendus** (en quantité totale
issue de `order_items`), avec leur rang au sein de la catégorie.
Utilisez une fonction de fenêtrage (`ROW_NUMBER()` ou `RANK()` avec `PARTITION BY`).

Retourner : nom de la catégorie, nom du produit, quantité totale vendue, rang.
Demandez à Claude d'expliquer la différence entre `ROW_NUMBER`, `RANK` et `DENSE_RANK`
en cas d'égalité de quantités.
