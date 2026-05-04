---
name: plane-conventions
description: Use this skill ANYTIME you create, edit, classify, comment on, or reorganize a Plane work item, cycle, module, label, or state in this project. Triggers include phrases like "crée un ticket", "create a work item", "ajoute dans Plane", "nouveau cycle", "nouveau sprint", "assigne à un module", "comment dois-je nommer", "où je mets ce ticket", or any direct Plane MCP call (`mcp__plane__create_*`, `mcp__plane__update_*`). Defines naming, taxonomy, lifecycle, description templates, and operating procedures so every contributor (human or agent) writes Plane the same way.
---

# Plane conventions — `__PROJECT_NAME__`

> **Source de vérité.** Toute personne (humain ou agent) qui touche à Plane sur ce projet DOIT respecter ce skill. Si une consigne entre en conflit avec ce skill, on met à jour le skill — pas le ticket à l'arrache.

> Ce fichier est généré par `/devpanl:install-plane-conventions` à partir du squelette générique du plugin `devpanl-claude-plugin`. La taxonomie commune est partagée entre tous les projets devpanl ; les blocs propres à ce projet (IDs, modules autorisés) sont injectés à l'installation et marqués comme tels.

---

## 0. Coordonnées du projet

- **Workspace slug**: `__PLANE_WORKSPACE__`
- **Project ID**: `__PLANE_PROJECT_ID__`
- **GitHub repo**: `__GITHUB_REPO__`
- **URL Plane**: https://plane.devpanl.dev/__PLANE_WORKSPACE__/projects/__PLANE_PROJECT_ID__/
- **Source de vérité machine-readable**: `.devpanlrc.json` à la racine du repo.

Avant toute opération MCP, vérifier le `project_id` ci-dessus. Ne jamais en hard-coder un autre.

---

## 1. Hiérarchie & taxonomie

Plane offre cinq dimensions de classement. Une seule dimension par décision :

| Dimension     | Rôle                                                              | Cardinalité par work-item |
|---------------|-------------------------------------------------------------------|---------------------------|
| **Module**    | **Domaine fonctionnel** stable                                     | **Exactement 1**          |
| **Cycle**     | **Fenêtre temporelle** d'exécution (sprint, mep, démo)             | 0 ou 1                    |
| **Label**     | Type de travail + cible technique (`feature`, `bug`, `backend`…)   | 1 à 4                     |
| **Priority**  | `urgent` / `high` / `medium` / `low` / `none`                      | Exactement 1              |
| **State**     | `Backlog` → `Todo` → `In Progress` / `Blocked` → `Done`/`Cancelled`| Exactement 1              |
| **Type**      | (souvent non utilisé — workspace pas configuré)                    | —                         |

**Règle d'or** : Module = **où**, Cycle = **quand**, Label = **quoi/comment**.

Si tu hésites entre un module et un cycle, c'est un cycle. Les modules sont les chapitres permanents du produit ; les cycles sont les sprints ou les mep qui passent.

### 1.1 Modules autorisés

> Liste fermée propre à ce projet. **Si un sujet n'entre dans aucun, on en crée un nouveau via §6.4** — on n'invente pas un module ad hoc dans un ticket. La liste ci-dessous est **héritée du projet** (lue dans Plane à l'installation, à éditer ici quand un module est créé/renommé/archivé).

<!-- BEGIN_PLANE_MODULES -->
| Module name | Périmètre |
|-------------|-----------|
| `__SET_ME__` | À remplir : décrire en une phrase ce que ce module couvre. |
<!-- END_PLANE_MODULES -->

⚠️ **Anti-pattern à éviter** : ne pas créer de module fourre-tout (du genre `MISC`, `DEVKORA`, `Various`). Si tu hésites, classe dans le module fonctionnel correct.

### 1.2 Labels autorisés

Trois familles. Maximum 4 labels par ticket.

**Type de travail (obligatoire, exactement 1)** :
- `feature` — nouvelle fonctionnalité utilisateur
- `bug` — régression ou comportement incorrect
- `architecture` — design, refacto structurant, ADR
- `qa` — tests E2E, plan de test, scénarios

**Stack visée (recommandé, 0 à 2)** :
- `backend` — API, modèles, services, jobs
- `fullstack` — UI + intégration backend (si touche les deux)
- `devops` — Docker, CI/CD, déploiement

**Cycle de vie (optionnel, 0 ou 1)** :
- `claude-ready` — ticket suffisamment cadré pour qu'un agent l'attaque seul
- `production` — touche directement la prod (mep, hotfix)
- `dev` — chantier en cours, pas prêt pour planif

**Doublons à NE PAS recréer** : les labels qui répliquent un module (ex. `campus`, `admission`) sont de la dette. **Le module remplit ce rôle.** N'ajoute plus ces labels aux nouveaux tickets, et migre quand tu y touches.

### 1.3 États (workflow)

```
Backlog ──▶ Todo ──▶ In Progress ──▶ Done
   │          │           │
   │          │           └──▶ Blocked (en attente humain) ──▶ In Progress
   │          │
   └──────────┴───────────────────▶ Cancelled (abandonné, JAMAIS supprimé)
```

- **Backlog** : pas encore prêt à être pris.
- **Todo** : prêt, attend un assigné/un cycle.
- **In Progress** : quelqu'un (humain ou agent) bosse dessus *maintenant*.
- **Blocked** : nécessite une décision/réponse externe. Toujours commenter pourquoi.
- **Done** : code mergé OU décision actée. Ne pas marquer Done sur la simple PR ouverte.
- **Cancelled** : abandonné. On garde l'historique, on ne supprime pas.

### 1.4 Priorités

| Niveau   | Quand l'utiliser                                                         | SLA implicite   |
|----------|--------------------------------------------------------------------------|-----------------|
| `urgent` | Bloque la prod, démo client, ou un cycle critique                        | < 24h           |
| `high`   | Sprint actuel, dépendance d'autres tickets                               | dans le cycle   |
| `medium` | Backlog actif, à faire bientôt                                           | 1–2 cycles      |
| `low`    | Nice-to-have, dette technique non bloquante                              | quand on peut   |
| `none`   | Pas encore trié                                                          | —               |

Toujours mettre une priorité explicite à la création — ne pas laisser `none`.

---

## 2. Nomenclature des work-items

### 2.1 Format du titre

```
[<TAG>] <verbe à l'impératif> <objet> — <précision optionnelle>
```

- **`<TAG>`** : préfixe court entre crochets qui dit *quel type de travail*. Choisis exactement un dans la liste ci-dessous.
- **`<verbe à l'impératif>`** : « Ajouter », « Corriger », « Refactorer », « Documenter », « Migrer », « Désactiver »…
- **`<objet>`** : la chose visée (composant, route, écran, modèle).
- **`<précision optionnelle>`** : contexte court après un tiret cadratin `—`.

### 2.2 Tags autorisés

| Tag           | Usage                                                                  | Exemple                                              |
|---------------|------------------------------------------------------------------------|------------------------------------------------------|
| `[FEAT]`      | Nouvelle feature utilisateur                                            | `[FEAT] Ajouter export CSV des paiements`            |
| `[BUG]`       | Correction de bug                                                       | `[BUG] Corriger confirmation suppression FileExplorer` |
| `[ARCHI]`     | Conception, ADR, contrat inter-systèmes                                 | `[ARCHI] Définir contrat UTM A↔B`                    |
| `[REFACTO]`   | Restructure interne, pas de changement fonctionnel                      | `[REFACTO] Extraire conversationService`             |
| `[INFRA]`     | Docker, CI, secrets, observabilité                                      | `[INFRA] Wire GlitchTip SDK côté server`             |
| `[DOC]`       | Documentation interne ou utilisateur                                    | `[DOC] Documenter le flow d'admission`               |
| `[QA]`        | Plan de test, écriture de tests, scénarios E2E                          | `[QA] Tester le pipeline candidat → inscrit`         |
| `[DEMO]`      | Préparation d'une démo (a une date de péremption)                       | `[DEMO] Stub données pour démo 12/05`                |
| `[SPIKE]`     | Investigation cadrée (timeboxée) avant de pouvoir trancher              | `[SPIKE] Évaluer Permify vs Casbin`                  |
| `[CHORE]`     | Tâche de maintenance non-fonctionnelle (deps, lockfile, cleanup)        | `[CHORE] Régénérer package-lock.json sur Linux`      |

⛔ **Préfixes interdits** (vus dans l'historique, ne plus utiliser) : casse hétérogène (`[Archi]` vs `[ARCHI]`), phase/stack dans le titre (`[P4·FE]`, `[Day1]`, `[W18]`), parenthèses (`(BUG)`). La phase et la stack ne vont **pas** dans le titre — elles vont dans le cycle et les labels.

### 2.3 Règles supplémentaires

- Titre **en français** par défaut (langue d'équipe). Anglais autorisé si le sujet est tech-only et que l'équipe concernée est anglophone.
- Longueur cible : **60–90 caractères**, max 110.
- Pas de point final.
- Pas de numéro de ticket dans le titre (Plane le génère via `sequence_id`).
- Si le titre dépasse 110 caractères, c'est probablement deux tickets.

### 2.4 Exemples bons / mauvais

| ❌ Mauvais                                                          | ✅ Bon                                                                  |
|---------------------------------------------------------------------|-------------------------------------------------------------------------|
| `Bug delete icon`                                                   | `[BUG] Corriger l'icône de suppression sur la vue détail document`      |
| `[P4·FE] TicketSlaSettings (admin only): CRUD sur TicketSlaConfig`  | `[FEAT] Ajouter page admin TicketSlaSettings`                           |
| `Admissions stuff`                                                  | `[FEAT] Ajouter filtre par programme dans la pipeline admissions`       |
| `Refactor`                                                          | `[REFACTO] Extraire conversationService de ChatThread`                  |
| `it works now`                                                      | `[BUG] Corriger redirection portail parent après login`                 |

---

## 3. Description du work-item

Toute description suit ce gabarit. **Pas de description vide.** Si tu n'as pas le contexte, c'est un `[SPIKE]` qui te le donnera.

````markdown
## Contexte
<Pourquoi ce ticket existe. D'où vient la demande (utilisateur, ADR, issue GH, conversation), quel problème il résout, quelles décisions sont déjà prises ailleurs.>

## Travail à faire
- Élément concret 1 (action atomique, vérifiable)
- Élément concret 2
- …

## Critères d'acceptation
- [ ] Comportement utilisateur observable A
- [ ] Comportement utilisateur observable B
- [ ] Tests : unit RTL OU backend Vitest selon stack
- [ ] Lint vert (`npm run lint`)
- [ ] Pas de régression sur les modules adjacents (lister lesquels)

## Fichiers à toucher
**Créer** : `path/to/new.jsx`
**Modifier** : `src/config/routes.js`, `src/App.jsx`
**Lire** : `docs/architecture/DESIGN_GUIDELINES.md`

## Dépendances
- Bloque : XXX-NNN
- Bloqué par : XXX-MMM
- Lien externe : ADR `docs/architecture/<doc>.md` / PR #NNN

## Notes
<Ce qui n'entre dans aucune section : pièges connus, alternatives écartées, contacts.>
````

### 3.1 Obligations par section

- **Contexte** : minimum 2 phrases. Pas de "as discussed".
- **Travail à faire** : 2 à 8 puces. Au-delà, scinder en plusieurs tickets.
- **Critères d'acceptation** : 3 à 6, **observables**. "Tests passent" tout seul ne compte pas.
- **Fichiers à toucher** : permet à un agent (humain ou Claude) de localiser sans grep.
- **Dépendances** : si rien, écrire `Aucune` — ne pas omettre.

### 3.2 Pour les bugs spécifiquement

Ajoute en haut de **Contexte** :

```markdown
**Reproduction**
1. Aller sur /xxx
2. Cliquer sur yyy
3. Observer : <comportement actuel>

**Attendu** : <comportement correct>
**Environnement** : prod / preprod / local — version commit/PR
```

### 3.3 Pour les `[ARCHI]`

Ajoute :

```markdown
## Décision attendue
<Format : ADR commenté, contrat de schéma, arbre de décision, etc.>

## Livrables
- Document `docs/architecture/<nom>.md`
- Commentaire de synthèse sur ce ticket
- (le cas échéant) tickets enfants créés
```

---

## 4. Cycles : quand, comment, nommage

### 4.1 Quand créer un cycle

Crée un cycle **uniquement** si :
1. Il a une **fenêtre de temps fixe** (start_date + end_date),
2. Il regroupe **3 à 25 tickets** d'un thème cohérent,
3. Quelqu'un est **owner** identifié (champ `owned_by`).

Si tu as juste « plein de trucs à faire dans <module> », c'est le **module** qui les porte, pas un cycle.

### 4.2 Format du nom du cycle

```
<TYPE> <PERIODE> — <thème>
```

| `<TYPE>`   | Quand                                                                | Exemple                                          |
|------------|----------------------------------------------------------------------|--------------------------------------------------|
| `Sprint`   | Itération hebdo/bi-hebdo régulière (du lundi au dimanche)            | `Sprint W19 — Portail étudiant Quick Wins`       |
| `MEP`      | Préparation d'une mise en production datée                           | `MEP 2026-05-15 — Admissions production-ready`   |
| `Demo`     | Préparation d'une démo client datée                                  | `Demo 2026-05-25 — Parcours candidat complet`    |
| `Hotfix`   | Cycle d'urgence (< 48h)                                              | `Hotfix 2026-05-04 — Crash login étudiant`       |
| `Phase`    | Tranche d'un gros chantier multi-cycles (P1, P2…)                    | `Phase 2 — Conversation polymorphe + Notifs`     |

Règles :
- **Date au format ISO** `YYYY-MM-DD` ou semaine ISO `Wxx` — jamais `28/04/2026` ni `Day1`.
- Pas d'abréviation maison (`mep1`, `daily-build-2`, `Petite démo du lundi` → tous bannis).
- Une seule tirade `—` (cadratin), pas de `:` ou de `/`.

### 4.3 Description du cycle

Toujours remplir, même brièvement :

```markdown
## Objectif
<En une phrase : qu'est-ce que ce cycle livre ?>

## Périmètre
- Inclus : <liste courte>
- Exclu : <liste courte si pertinent>

## Owner
<@user> — responsable du suivi quotidien

## Définition de "Done" pour ce cycle
- Toutes les tasks `Done` ou `Cancelled`
- (le cas échéant) Démo enregistrée / mep effectuée
```

### 4.4 Lifecycle d'un cycle

1. **Création** : statut backlog, owner défini, dates posées, description complète.
2. **Démarrage** : à `start_date`, on bouge les tickets en `Todo`/`In Progress`. Pas avant.
3. **En cours** : daily review dans le cycle, pas en dehors.
4. **Clôture** : à `end_date`, les tickets non-finis basculent **explicitement** soit dans le cycle suivant, soit sans cycle.
5. **Pas de cycle "fourre-tout"** qui s'étire sur 6 mois. Un cycle qui dérape de plus de 50 % de sa durée doit être split.

---

## 5. Modules : quand en créer un

### 5.1 Critères pour créer un module

Tous doivent être vrais :
- Le sujet va vivre **plus de 3 cycles**.
- Il existe un **owner produit** identifié.
- Il a une **vision/charter** documentée (description du module ≥ 5 lignes).
- Il ne recouvre aucun module existant à 80 %.

Sinon : utilise un module existant + un label/cycle.

### 5.2 Description d'un module

Le champ `description` du module sert de charter. Modèle minimal :

```markdown
# <Nom du module> — Charter

## Vision
<1 paragraphe.>

## Périmètre
- Couvre : <liste>
- Ne couvre pas : <liste>

## Modules adjacents
- Lien avec `<autre module>` : <interface, contrat>

## Owner produit
<@user>

## Documents de référence
- `docs/architecture/<doc>.md`
- ADR : <liens>

## Statut
backlog | in-progress | paused | done
```

### 5.3 Anti-patterns observés

- **Module fourre-tout** (`MISC`, `Various`, ou un module historique surchargé) → à scinder petit-à-petit vers les modules fonctionnels.
- **Module à 0 ticket depuis > 3 cycles** → soit on l'utilise, soit on l'archive.

---

## 6. Procédures opérationnelles

### 6.1 Créer un work-item (humain ou agent)

**Avant de créer** :
1. Cherche un doublon : `mcp__plane__search_work_items` avec 2-3 mots-clés du titre.
2. Identifie le **module** (§1.1).
3. Identifie le **cycle** courant (s'il existe).
4. Choisis **tag**, **labels**, **priorité**.

**Création** :
- Titre conforme §2.
- Description conforme §3.
- Assigner les bons IDs : `module_ids`, `label_ids`, `cycle_ids`, `assignee_ids`, `priority`.
- Laisser `state` à `Backlog` (par défaut) sauf si l'agent prend immédiatement.

**Après création** :
- Si le ticket est `claude-ready`, ajouter le label.
- Notifier l'owner du module/cycle si critique.

### 6.2 Mettre à jour un work-item

- **Changer de module** : autorisé seulement si on s'est trompé. Sinon, scinde le ticket.
- **Changer de cycle** : autorisé en milieu de cycle uniquement avec justification dans un commentaire.
- **Changer la priorité** : commenter le pourquoi.
- **Marquer Done** : la PR doit être **mergée**, pas seulement ouverte. Pour les `[ARCHI]`, le doc doit exister.

### 6.3 Commenter un work-item

Commentaire = trace d'avancement. À utiliser quand :
- On bloque (pourquoi, qui peut débloquer).
- On change de plan.
- On livre (lien commit / PR).
- On dispatche à un agent (mention le SOUL).

Format conseillé :
```
[YYYY-MM-DD HH:mm Europe/Paris] @auteur — <action en 1 phrase>
<détails optionnels>
```

### 6.4 Créer un module

1. Vérifier les critères §5.1.
2. Créer via `mcp__plane__create_module` avec name + description charter §5.2.
3. Mettre à jour ce skill : ajouter une ligne dans le tableau §1.1.
4. Mettre à jour `.devpanlrc.json` si pertinent.
5. Communiquer à l'équipe.

### 6.5 Créer un cycle

1. Vérifier les critères §4.1.
2. Créer via `mcp__plane__create_cycle` avec :
   - `name` au format §4.2,
   - `description` §4.3,
   - `start_date`, `end_date`, `owned_by`.
3. Y rattacher les tickets via `mcp__plane__add_work_items_to_cycle`.

### 6.6 Cleanup périodique

Une fois par sprint, le PM passe :
- Clôturer les cycles expirés.
- Supprimer les cycles vides plus vieux que 30 jours.
- Migrer les tickets `In Progress` sans commit ≥ 14 j en `Blocked` ou `Backlog`.
- Réassigner les tickets `Backlog` sans module au bon module.
- Repérer les tickets sans description / sans label `feature|bug|architecture|qa` et les compléter.

---

## 7. Pour les agents Claude (SOUL hooks)

Quand un agent (architect, backend, fullstack, qa, devops, designer, pm…) crée ou modifie un work-item :

1. **Toujours invoquer ce skill** avant tout `mcp__plane__create_*` ou `mcp__plane__update_*`.
2. **Auto-vérifier** :
   - Titre matche regex `^\[(FEAT|BUG|ARCHI|REFACTO|INFRA|DOC|QA|DEMO|SPIKE|CHORE)\] .{20,}$`.
   - `module_ids` non vide.
   - `priority` ≠ `none`.
   - Description ≥ 200 caractères et contient les sections "Contexte", "Travail à faire", "Critères d'acceptation".
3. Si une de ces conditions échoue : **ne pas créer**, demander/compléter d'abord.
4. À la fin de l'action, ajouter un commentaire `[<date>] @<agent> — <résumé>`.

---

## 8. Quick reference (cheat sheet)

```
┌──────────────────────────────────────────────────────────────────────────┐
│ TITRE   : [TAG] verbe + objet + — précision        (60–90 chars, FR)     │
│ MODULE  : exactement 1 dans la liste fermée                              │
│ CYCLE   : si fenêtre temporelle + 3–25 tickets + owner                   │
│ LABELS  : 1 type (feature|bug|architecture|qa) + 0–2 stack + 0–1 lifecycle│
│ PRIO    : urgent|high|medium|low (jamais none à la création)             │
│ STATE   : Backlog → Todo → In Progress → Done (Blocked/Cancelled latéraux)│
│ DESC    : Contexte / Travail / Critères / Fichiers / Deps / Notes        │
└──────────────────────────────────────────────────────────────────────────┘
```

### IDs pratiques (résolus à l'installation, à rafraîchir si Plane drift)

> Bloc auto-rempli par `/devpanl:install-plane-conventions` quand `PLANE_TOKEN` est dans l'env. Sinon, placeholders à compléter à la main via `mcp__plane__list_states / list_modules / list_labels`.

<!-- BEGIN_PLANE_IDS -->
```
project_id  = __PLANE_PROJECT_ID__
state.*     = __SET_ME__
module.*    = __SET_ME__
label.*     = __SET_ME__
```
<!-- END_PLANE_IDS -->

> En cas de drift, refaire un `mcp__plane__list_states / list_modules / list_labels` ou ré-exécuter `/devpanl:install-plane-conventions` avec `PLANE_TOKEN` exporté.

---

## 9. Évolution de ce skill

- Ce skill est versionné dans `.claude/skills/plane-conventions/SKILL.md`.
- Le squelette générique vient du plugin `devpanl-claude-plugin` (skill `plane-conventions`). Pour faire évoluer la **taxonomie commune** (titres, labels, lifecycle), PR sur le plugin. Pour faire évoluer ce qui est **propre à ce projet** (modules autorisés, IDs), PR sur ce repo.
- **Toute modification = PR**, pas de commit direct sur main.
- Ajouter en bas une ligne dans le changelog ci-dessous.

### Changelog

- Initial install via `/devpanl:install-plane-conventions`.
