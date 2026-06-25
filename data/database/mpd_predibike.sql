-- ============================================================
-- MPD — Projet PrediBike (prédiction du risque accident vélo)
-- SGBD cible : PostgreSQL 16+ avec extension PostGIS
-- ============================================================

-- Extension nécessaire pour le type GEOGRAPHY et les fonctions
-- spatiales (ST_DWithin, etc.) utilisées pour la jointure
-- géographique avec les aménagements cyclables
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- TABLE : COMMUNE
-- Source : base SQL INSEE (4e source de données obligatoire)
-- ============================================================
CREATE TABLE commune (
    code_insee      VARCHAR(5)      PRIMARY KEY,
    nom_commune     VARCHAR(100)    NOT NULL,
    population      INTEGER         NOT NULL CHECK (population >= 0),
    superficie      DECIMAL(8,2)    NOT NULL CHECK (superficie > 0), -- en km²
    departement     VARCHAR(3)      NOT NULL
);

COMMENT ON TABLE commune IS 'Référentiel des communes, enrichi via données INSEE';
COMMENT ON COLUMN commune.superficie IS 'Superficie en km², utilisée pour calculer la densité (population/superficie)';

-- ============================================================
-- TABLE : CONDITION_METEO
-- Source : API REST publique (météo)
-- ============================================================
CREATE TABLE condition_meteo (
    id_releve           SERIAL          PRIMARY KEY,
    temperature         DECIMAL(4,1),               -- en °C
    precipitation_mm    DECIMAL(5,1)    NOT NULL CHECK (precipitation_mm >= 0)
);

COMMENT ON TABLE condition_meteo IS 'Relevés météo associés au moment et lieu de chaque accident';

-- ============================================================
-- TABLE : AMENAGEMENT_CYCLABLE
-- Source : scraping web (sites municipaux / métropoles)
-- Pas de FK vers ACCIDENT : la proximité est calculée à la
-- demande via requête spatiale (voir requêtes plus bas),
-- car les aménagements évoluent dans le temps indépendamment
-- des accidents historiques.
-- ============================================================
CREATE TABLE amenagement_cyclable (
    id_amenagement      SERIAL                          PRIMARY KEY,
    type_amenagement    VARCHAR(30)                     NOT NULL,
    geom                GEOGRAPHY(POINT, 4326)          NOT NULL
);

COMMENT ON TABLE amenagement_cyclable IS 'Infrastructures cyclables (pistes, zones 30...) issues du scraping municipal';
COMMENT ON COLUMN amenagement_cyclable.type_amenagement IS 'Ex: piste_separee, bande_cyclable, zone_30, voie_verte';
COMMENT ON COLUMN amenagement_cyclable.geom IS 'Point géographique WGS84 (SRID 4326), type PostGIS';

-- ============================================================
-- TABLE : ACCIDENT
-- Source : CSV BAAC (data.gouv.fr, fichiers Caractéristiques
-- + Lieux + Véhicules agrégés à l'ETL)
-- Table centrale du modèle, niveau de granularité = 1 accident
-- ============================================================
CREATE TABLE accident (
    id_accident             VARCHAR(15)     PRIMARY KEY,  -- identifiant officiel BAAC conservé
    date_heure              TIMESTAMP       NOT NULL,
    geom                    GEOGRAPHY(POINT, 4326) NOT NULL,
    gravite_max             VARCHAR(20)     NOT NULL
                                CHECK (gravite_max IN ('indemne','leger','grave','mortel')),
    nb_velos_muscu          SMALLINT        NOT NULL DEFAULT 0 CHECK (nb_velos_muscu >= 0),
    nb_velos_electriques    SMALLINT        NOT NULL DEFAULT 0 CHECK (nb_velos_electriques >= 0),
    nb_vehicules_motorises  SMALLINT        NOT NULL DEFAULT 0 CHECK (nb_vehicules_motorises >= 0),
    code_insee              VARCHAR(5)      NOT NULL REFERENCES commune(code_insee),
    id_releve               INTEGER                  REFERENCES condition_meteo(id_releve)
);

COMMENT ON TABLE accident IS 'Table centrale : un accident impliquant au moins un vélo, niveau de granularité = accident';
COMMENT ON COLUMN accident.id_releve IS 'NULL autorisé : donnée météo parfois indisponible sur les accidents anciens (2005-2010)';

-- ============================================================
-- INDEX
-- ============================================================

-- Index spatiaux GIST : indispensables pour des requêtes
-- ST_DWithin performantes (sinon comparaison point à point
-- sur potentiellement des millions de lignes)
CREATE INDEX idx_accident_geom ON accident USING GIST (geom);
CREATE INDEX idx_amenagement_geom ON amenagement_cyclable USING GIST (geom);

-- Index classiques sur les colonnes de filtrage/jointure fréquentes
CREATE INDEX idx_accident_commune ON accident (code_insee);
CREATE INDEX idx_accident_date ON accident (date_heure);

-- ============================================================
-- REQUÊTES SQL D'EXEMPLE — démonstration des cas d'usage clés
-- ============================================================

-- 1. Tous les accidents vélo d'une commune donnée (jointure simple)
-- SELECT a.*, c.nom_commune
-- FROM accident a
-- JOIN commune c ON a.code_insee = c.code_insee
-- WHERE c.code_insee = '69123'; -- Lyon

-- 2. Nombre d'accidents par commune, avec densité de population
--    (illustre l'usage métier de superficie + population)
-- SELECT
--     c.nom_commune,
--     COUNT(a.id_accident) AS nb_accidents,
--     ROUND(c.population / c.superficie, 1) AS densite_hab_km2
-- FROM commune c
-- LEFT JOIN accident a ON a.code_insee = c.code_insee
-- GROUP BY c.code_insee, c.nom_commune, c.population, c.superficie
-- ORDER BY nb_accidents DESC;

-- 3. Requête spatiale : aménagements cyclables à moins de 200m
--    d'un accident donné (PAS de FK stockée — calcul à la demande)
-- SELECT am.id_amenagement, am.type_amenagement
-- FROM amenagement_cyclable am, accident a
-- WHERE a.id_accident = '202400012345'
--   AND ST_DWithin(am.geom, a.geom, 200); -- distance en mètres

-- 4. Même logique, mais pour un NOUVEAU lieu saisi par l'utilisateur
--    dans l'application (cas d'usage temps réel / prédiction)
-- SELECT type_amenagement
-- FROM amenagement_cyclable
-- WHERE ST_DWithin(
--     geom,
--     ST_SetSRID(ST_MakePoint(:longitude_utilisateur, :latitude_utilisateur), 4326),
--     200
-- );

-- 5. Accidents vélo par condition météo (corrélation risque/pluie)
-- SELECT
--     CASE WHEN cm.precipitation_mm > 0 THEN 'pluie' ELSE 'sec' END AS condition,
--     COUNT(*) AS nb_accidents,
--     AVG(a.nb_velos_electriques) AS moyenne_velos_elec
-- FROM accident a
-- JOIN condition_meteo cm ON a.id_releve = cm.id_releve
-- GROUP BY condition;
