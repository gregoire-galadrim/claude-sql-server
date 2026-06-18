---
name: dire-bonjour
description: Salue chaleureusement l'utilisateur au nom du projet "Exercices SQL". Déclenche ce skill dès que l'utilisateur ouvre l'échange par une salutation — "bonjour", "salut", "coucou", "hello", "hey", "yo", "wesh", etc. — même seule ou suivie d'autre chose. Le but est de donner un accueil cohérent et reconnaissable à chaque début d'interaction sur ce projet.
---

# Dire bonjour

Quand l'utilisateur te salue, réponds par un mot d'accueil bref, chaleureux et propre au projet **Exercices SQL**, puis enchaîne naturellement sur sa demande s'il y en a une.

## Pourquoi

Un accueil cohérent rend le projet plus accueillant et rappelle discrètement à l'utilisateur dans quel contexte il travaille (sa base d'entraînement SQL). L'idée n'est pas de réciter une formule figée mais de poser un ton amical et stable d'une session à l'autre.

## Comment saluer

Garde la salutation courte (une à deux phrases). Inclus ces éléments :

- une formule de bienvenue chaleureuse en français ;
- une touche qui rappelle le projet (les exercices SQL, la base d'entraînement) ;
- une transition vers ce que l'utilisateur veut faire.

Adapte le registre à celui de l'utilisateur : s'il écrit "bonjour", reste poli et posé ; s'il écrit "salut" ou "wesh", tu peux être plus décontracté. Reste sincère et évite d'en faire trop — pas de débauche d'emojis ni d'enthousiasme forcé.

Si la salutation est accompagnée d'une vraie demande, salue en une phrase puis traite la demande sans t'attarder. Le bonjour ne doit jamais retarder le travail.

## Exemples

**Exemple 1 — salutation seule**
Entrée : `Bonjour`
Sortie : `Bonjour Grégoire ! Content de te retrouver sur tes exercices SQL. Sur quoi veux-tu avancer aujourd'hui ?`

**Exemple 2 — registre décontracté**
Entrée : `Salut !`
Sortie : `Salut ! Prêt à jouer avec la base d'entraînement ? Dis-moi ce que tu cherches à faire.`

**Exemple 3 — salutation + demande**
Entrée : `Coucou, tu peux me lister les tables de la base ?`
Sortie : `Coucou ! Bien sûr, je regarde les tables de la base tout de suite.` *(puis traite la demande)*
