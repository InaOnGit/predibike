# Modèle Physique des Données (MPD) — PrediBike

## SGBD cible

**PostgreSQL 16+** avec l'extension **PostGIS**.

Justification du choix de PostGIS : le projet manipule des coordonnées
géographiques (lieux d'accidents, localisation des aménagements cyclables)
et nécessite des calculs de proximité spatiale (« cet aménagement est-il à
moins de 200m de ce point ? »). PostGIS fournit un type natif `GEOGRAPHY`
et des fonctions dédiées (`ST_DWithin`, notamment) qui rendent ces calculs
fiables et performants, sans recalcul trigonométrique manuel sur deux
colonnes `latitude`/`longitude` séparées.

## Script SQL complet

Le script de création de la base se trouve dans
[`data/database/mpd_predibike.sql`](../data/database/mpd_predibike.sql).
Il contient l'activation de l'extension PostGIS, la création des 4 tables
avec leurs contraintes et index, ainsi que des requêtes SQL d'exemple
illustrant les cas d'usage clés du projet (commentées, à activer une fois
la base peuplée).

## Détail des tables

### COMMUNE

| Colonne | Type | Contrainte |
|---|---|---|
| code_insee | `VARCHAR(5)` | PRIMARY KEY |
| nom_commune | `VARCHAR(100)` | NOT NULL |
| population | `INTEGER` | NOT NULL, CHECK >= 0 |
| superficie | `DECIMAL(8,2)` | NOT NULL, CHECK > 0 (km²) |
| departement | `VARCHAR(3)` | NOT NULL |

`code_insee` est stocké en `VARCHAR` et non en entier : certains codes
commencent par un zéro significatif ou contiennent des lettres (Corse :
2A/2B) — un type numérique romprait ces valeurs.

### CONDITION_METEO

| Colonne | Type | Contrainte |
|---|---|---|
| id_releve | `SERIAL` | PRIMARY KEY |
| temperature | `DECIMAL(4,1)` | — (°C) |
| precipitation_mm | `DECIMAL(5,1)` | NOT NULL, CHECK >= 0 |

### AMENAGEMENT_CYCLABLE

| Colonne | Type | Contrainte |
|---|---|---|
| id_amenagement | `SERIAL` | PRIMARY KEY |
| type_amenagement | `VARCHAR(30)` | NOT NULL |
| geom | `GEOGRAPHY(POINT, 4326)` | NOT NULL |

`latitude`/`longitude` sont fusionnées en une seule colonne `geom` de type
PostGIS plutôt que deux colonnes numériques séparées, pour permettre
l'usage direct des fonctions spatiales (distance, proximité). Le SRID
`4326` correspond au système de coordonnées GPS standard (WGS84).

### ACCIDENT

| Colonne | Type | Contrainte |
|---|---|---|
| id_accident | `VARCHAR(15)` | PRIMARY KEY |
| date_heure | `TIMESTAMP` | NOT NULL |
| geom | `GEOGRAPHY(POINT, 4326)` | NOT NULL |
| gravite_max | `VARCHAR(20)` | NOT NULL, CHECK IN ('indemne','leger','grave','mortel') |
| nb_velos_muscu | `SMALLINT` | NOT NULL DEFAULT 0, CHECK >= 0 |
| nb_velos_electriques | `SMALLINT` | NOT NULL DEFAULT 0, CHECK >= 0 |
| nb_vehicules_motorises | `SMALLINT` | NOT NULL DEFAULT 0, CHECK >= 0 |
| code_insee | `VARCHAR(5)` | NOT NULL, FOREIGN KEY → commune(code_insee) |
| id_releve | `INTEGER` | FOREIGN KEY → condition_meteo(id_releve), nullable |

`id_releve` accepte la valeur NULL : la donnée météo peut être indisponible
pour les accidents les plus anciens (2005-2010).

`SMALLINT` est utilisé pour les compteurs de véhicules : un accident
n'implique jamais un nombre de véhicules nécessitant un entier 32 bits, et
ce choix réduit légèrement l'empreinte de stockage sur 20 ans de données.

## Index

```sql
CREATE INDEX idx_accident_geom ON accident USING GIST (geom);
CREATE INDEX idx_amenagement_geom ON amenagement_cyclable USING GIST (geom);
CREATE INDEX idx_accident_commune ON accident (code_insee);
CREATE INDEX idx_accident_date ON accident (date_heure);
```

Les index `GIST` sur les colonnes `geom` sont indispensables aux requêtes
spatiales (`ST_DWithin`) : sans eux, chaque requête de proximité devrait
comparer la distance entre un point et l'ensemble des lignes de la table,
ce qui deviendrait très lent à l'échelle de 20 ans de données nationales.

Les index sur `code_insee` et `date_heure` accélèrent les filtres et
agrégations courants de l'application (accidents par commune, par période).

## Cas d'usage illustrés par les requêtes d'exemple

1. Liste des accidents d'une commune donnée (jointure simple)
2. Nombre d'accidents par commune avec densité de population calculée
3. Aménagements cyclables à proximité d'un accident historique (requête
   spatiale sur les données existantes, pour l'entraînement du modèle)
4. Aménagements cyclables à proximité d'un nouveau lieu saisi par
   l'utilisateur (même requête spatiale, appliquée en temps réel pour la
   prédiction — cas d'usage central de l'application)
5. Corrélation entre conditions météo et profil des accidents (vélos
   électriques vs musculaires)
