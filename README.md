# PrediBike

Application d'aide à la décision budgétaire pour les communes de la
région Rhône-Alpes, basée sur la prédiction du risque d'accident vélo.

Projet réalisé dans le cadre de la certification RNCP Développeur en
Intelligence Artificielle (Simplon AURA).

## Objectif

PrediBike n'est pas une plateforme grand public, mais un outil destiné
aux collectivités : à partir d'un lieu donné, l'application estime un
score de risque d'accident vélo et propose des recommandations
d'aménagement cyclable. L'objectif est d'aider les communes à objectiver
leurs demandes de travaux et à prioriser les investissements auprès de la
région, dans un contexte de budgets limités.

L'application se positionne comme un **composant d'aide à la décision**,
en amont de la validation des projets et des budgets — elle ne remplace
pas l'arbitrage politique ou technique, elle fournit un élément
d'objectivation supplémentaire.

Pour le détail complet du contexte et des choix techniques, voir
[`docs/architecture.md`](docs/architecture.md).

## Structure du dépôt

```
predibike/
├── docs/                   # documentation du projet
│   ├── architecture.md     # architecture technique et choix justifiés
│   ├── mcd.md               # modèle conceptuel des données
│   ├── mld.md               # modèle logique des données
│   ├── mpd.md               # modèle physique des données
│   ├── journal.md           # journal d'avancement, semaine par semaine
│   └── assets/               # schémas exportés (SVG)
├── data/
│   ├── etl/                 # scripts de collecte et nettoyage (à venir)
│   └── database/
│       └── mpd_predibike.sql # script de création de la base PostgreSQL
├── ia/                       # modèle de prédiction et API IA (à venir)
├── app/                      # application finale Streamlit (à venir)
├── .github/workflows/
│   └── release.yml          # CI/CD — versionnement automatisé
└── .releaserc.json           # configuration semantic-release
```

## Sources de données

| Source | Type | Contenu |
|---|---|---|
| CSV BAAC (data.gouv.fr) | Fichier | Historique accidents corporels vélo, 2005-2024 |
| API météo | API REST publique | Conditions météo au lieu/moment de l'accident |
| Sites municipaux | Scraping web | Zones 30, aménagements cyclables |
| Données communales INSEE | Base SQL | Population, superficie par commune |

## Stack technique

- **Langage** : Python
- **Données** : PostgreSQL + PostGIS, pandas
- **IA** : scikit-learn, MLflow
- **API** : FastAPI
- **Application** : Streamlit
- **CI/CD** : GitHub Actions, Docker, semantic-release
- **Monitoring** : Prometheus, Grafana

## État d'avancement

Voir [`docs/journal.md`](docs/journal.md) pour le suivi détaillé,
semaine par semaine.

État actuel : conception terminée (architecture, MCD, MLD, MPD) —
collecte des données en cours.

## Licence

Projet pédagogique réalisé dans le cadre d'une certification RNCP.
