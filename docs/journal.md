# Journal d'avancement — PrediBike

Ce journal retrace, semaine par semaine, les décisions prises et leur
justification. Objectif : servir de support de préparation aux oraux de
certification (E1 à E5), en gardant une trace du raisonnement au moment où
il a été fait — plus fiable qu'une reconstruction a posteriori plusieurs
mois après.

---

## Semaine 1 — Cadrage et conception (23-25 juin 2026)

### Choix du sujet

Prédiction du risque d'accident vélo en région Rhône-Alpes (extensible à
la France entière selon volume de données disponible), à partir de
l'historique BAAC (2005-2024).

**Évolution du positionnement en cours de semaine** : le projet a été
recadré d'un usage grand public ("aide au cycliste") vers un usage
d'aide à la décision budgétaire pour les communes — l'application devient
un composant d'objectivation dans la chaîne de validation des projets et
budgets d'aménagement cyclable. Ce recadrage a des conséquences directes :
priorité donnée à l'interprétabilité du modèle (un score doit être
défendable devant un élu), et au fait de fournir des recommandations
actionnables (pas seulement un score brut).

### Architecture technique

Trois blocs alignés sur le référentiel de certification (Data / IA / App),
eux-mêmes reflétés dans l'arborescence du dépôt (`data/`, `ia/`, `app/`).
Stack imposée par le référentiel respectée : FastAPI, PostgreSQL,
Streamlit, MLflow, Prometheus/Grafana, GitHub Actions, Docker.

Choix techniques notables et leur justification :
- **PostgreSQL + PostGIS** plutôt que MySQL/SQLite : nécessité de calculer
  des proximités géographiques (accident ↔ aménagement cyclable) de façon
  fiable et performante.
- **scikit-learn plutôt qu'un service IA externe ou un LLM** : après veille
  technique, aucun service généraliste ne couvre ce besoin précis ; un
  modèle de ML classique est par ailleurs plus interprétable, plus léger
  (cohérent avec l'éco-conception) et plus adapté à des données tabulaires
  structurées.
- **semantic-release** intégré dès la semaine 1 : versionnement automatisé
  du dépôt, justifié notamment par le besoin de traçabilité (quelle
  version du modèle a produit telle recommandation budgétaire).

Voir [`architecture.md`](architecture.md) pour le détail complet.

### Sources de données — 4 types couverts

| Source | Type référentiel | Détail |
|---|---|---|
| CSV BAAC (Caractéristiques, Lieux, Véhicules) | Fichier | data.gouv.fr, 2005-2024 |
| API météo | API REST publique | À déterminer précisément (Météo-France ou OpenWeather) |
| Sites municipaux (zones 30, aménagements) | Scraping web | Pistes concrètes à valider en semaine 2 (voir point ouvert ci-dessous) |
| Données communales INSEE | Base SQL | Population, superficie — chargées en base relationnelle locale pour usage de jointures SQL |

Point de méthode important tranché cette semaine : il n'existe pas, en
pratique, de vraie base SQL distante publique accessible en lecture. La
"source SQL" du référentiel est interprétée comme une donnée nativement
structurée en relationnel (ici, les données communales INSEE), chargée et
requêtée (jointures) dans une base locale — démarche assumée et
documentée plutôt que contournée.

### Modélisation des données (MCD → MLD → MPD)

**Granularité retenue : niveau accident** (1 ligne = 1 accident), et non
niveau usager. Choix justifié par l'objectif du projet (cartographie du
risque par zone/conditions, pas analyse de profils individuels) et par la
généralisabilité recherchée (un modèle au niveau accident est réutilisable
hors du contexte français, contrairement à un modèle appris sur des
profils d'usagers très spécifiques à l'historique national).

Conséquence directe : les entités `USAGER` et `VEHICULE` ont été
**volontairement exclues** du MCD comme entités séparées. Leur information
utile est absorbée en attributs agrégés sur `ACCIDENT`
(`nb_velos_muscu`, `nb_velos_electriques`, `nb_vehicules_motorises`),
calculés à l'ETL. Argument à reformuler à l'oral si la question est posée :
*"je n'ai pas besoin d'analyser un véhicule ou un usager individuellement,
seulement de savoir, pour chaque accident, quels types étaient impliqués
et en quel nombre."*

4 entités retenues : `ACCIDENT`, `COMMUNE`, `CONDITION_METEO`,
`AMENAGEMENT_CYCLABLE`.

Point de modélisation notable : le lien entre `ACCIDENT` et
`AMENAGEMENT_CYCLABLE` n'est **pas** une association Merise classique
figée en base (pas de clé étrangère). Justification : les aménagements
évoluent dans le temps indépendamment des accidents passés, et la
proximité géographique doit être recalculée à la demande aussi bien sur
l'historique (entraînement du modèle) que sur un nouveau lieu saisi par
l'utilisateur (prédiction temps réel). Implémenté en MPD via une requête
spatiale PostGIS (`ST_DWithin`), pas une jointure classique.

Voir [`mcd.md`](mcd.md), [`mld.md`](mld.md), [`mpd.md`](mpd.md) pour le
détail complet, et [`../data/database/mpd_predibike.sql`](../data/database/mpd_predibike.sql)
pour le script exécutable.

### Livrables produits cette semaine

- [x] Architecture technique (`docs/architecture.md` + schéma)
- [x] MCD (`docs/mcd.md` + schéma)
- [x] MLD (`docs/mld.md` + schéma)
- [x] MPD (`docs/mpd.md` + script SQL exécutable)
- [x] Structure du dépôt Git
- [x] CI/CD — versionnement automatisé (semantic-release)

### Points ouverts pour la semaine 2

- Choisir précisément l'API météo (Météo-France vs OpenWeather) et tester
  l'accès
- Identifier une ou deux communes Rhône-Alpes concrètes dont le site
  expose des données de zones 30 / aménagements scrapables
- Démarrer l'ETL (`data/etl/`) : scripts d'extraction pour les 4 sources
- Exécuter et valider le script `mpd_predibike.sql` sur une instance
  PostgreSQL locale (Docker)
