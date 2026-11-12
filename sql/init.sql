-- data warehouse du projet séismes
-- exécuté automatiquement par postgres au tout premier démarrage (volume pgdata vide)
-- pour le rejouer : docker compose down -v (⚠️ efface toutes les données postgres)

-- ============================================================ gouvernance : rôles
-- etl_writer       : utilisé par spark pour charger les données (écriture)
-- dashboard_reader : utilisé par streamlit, LECTURE SEULE (access policy)
CREATE ROLE etl_writer       LOGIN PASSWORD 'etl_writer';
CREATE ROLE dashboard_reader LOGIN PASSWORD 'dashboard_reader';

CREATE SCHEMA dw AUTHORIZATION etl_writer;
GRANT USAGE ON SCHEMA dw TO dashboard_reader;

SET ROLE etl_writer;   -- tout ce qui suit appartient à etl_writer

-- ============================================================ couche temps réel
-- alimentée par le job spark streaming (upsert sur event_id)
CREATE TABLE dw.live_quakes (
    event_id      TEXT PRIMARY KEY,
    event_time    TIMESTAMPTZ NOT NULL,
    updated_at    TIMESTAMPTZ NOT NULL,       -- version USGS : sert à garder la plus récente
    mag           DOUBLE PRECISION,
    mag_type      TEXT,
    place         TEXT,
    region        TEXT,
    lon           DOUBLE PRECISION NOT NULL,
    lat           DOUBLE PRECISION NOT NULL,
    depth_km      DOUBLE PRECISION,
    event_type    TEXT,
    status        TEXT,                       -- automatic | reviewed
    tsunami       BOOLEAN,
    sig           INTEGER,
    alert         TEXT,
    url           TEXT,
    _ingested_at  TIMESTAMPTZ NOT NULL DEFAULT now(),   -- lineage
    _batch_id     BIGINT                                -- lineage : n° du micro-batch spark
);
CREATE INDEX idx_live_time ON dw.live_quakes (event_time DESC);

-- ============================================================ couche gold : schéma en étoile
-- remplie demain par le job gold (spark -> jdbc). le contrat est figé ici pour que
-- le dashboard puisse être codé en parallèle.

CREATE TABLE dw.dim_date (
    date_key   INTEGER PRIMARY KEY,        -- format AAAAMMJJ, ex 20240315
    full_date  DATE NOT NULL UNIQUE,
    year       SMALLINT NOT NULL,
    quarter    SMALLINT NOT NULL,
    month      SMALLINT NOT NULL,
    day        SMALLINT NOT NULL,
    weekday    SMALLINT NOT NULL           -- 1 = lundi ... 7 = dimanche
);

CREATE TABLE dw.dim_region (
    region_key  INTEGER PRIMARY KEY,
    region      TEXT NOT NULL UNIQUE
);

CREATE TABLE dw.dim_magnitude (
    mag_class_key  SMALLINT PRIMARY KEY,
    label          TEXT NOT NULL,           -- micro, mineur, léger, modéré, fort, majeur, grand
    min_mag        DOUBLE PRECISION NOT NULL,
    max_mag        DOUBLE PRECISION NOT NULL
);

CREATE TABLE dw.dim_depth (
    depth_class_key  SMALLINT PRIMARY KEY,
    label            TEXT NOT NULL,         -- superficiel, intermédiaire, profond
    min_km           DOUBLE PRECISION NOT NULL,
    max_km           DOUBLE PRECISION NOT NULL
);

CREATE TABLE dw.fact_earthquake (
    event_id         TEXT PRIMARY KEY,
    date_key         INTEGER  NOT NULL REFERENCES dw.dim_date(date_key),
    region_key       INTEGER  NOT NULL REFERENCES dw.dim_region(region_key),
    mag_class_key    SMALLINT NOT NULL REFERENCES dw.dim_magnitude(mag_class_key),
    depth_class_key  SMALLINT NOT NULL REFERENCES dw.dim_depth(depth_class_key),
    event_time       TIMESTAMPTZ NOT NULL,
    mag              DOUBLE PRECISION NOT NULL,
    depth_km         DOUBLE PRECISION NOT NULL,
    lon              DOUBLE PRECISION NOT NULL,
    lat              DOUBLE PRECISION NOT NULL,
    sig              INTEGER,
    felt             INTEGER,
    tsunami          BOOLEAN,
    alert            TEXT
);
-- index = les colonnes sur lesquelles le dashboard filtre / joint (cf. cours du 10 nov)
CREATE INDEX idx_fact_date   ON dw.fact_earthquake (date_key);
CREATE INDEX idx_fact_region ON dw.fact_earthquake (region_key);
CREATE INDEX idx_fact_mag    ON dw.fact_earthquake (mag);

-- agrégats pré-calculés (gold "prêt à servir") : le dashboard ne refait aucun gros calcul
CREATE TABLE dw.agg_region_month (
    region     TEXT     NOT NULL,
    year       SMALLINT NOT NULL,
    month      SMALLINT NOT NULL,
    n_quakes   INTEGER  NOT NULL,
    avg_mag    DOUBLE PRECISION,
    max_mag    DOUBLE PRECISION,
    PRIMARY KEY (region, year, month)
);

CREATE TABLE dw.agg_mag_distribution (     -- pour la loi de gutenberg-richter
    mag_bin    DOUBLE PRECISION PRIMARY KEY,   -- pas de 0.1
    n_quakes   BIGINT NOT NULL
);

RESET ROLE;

-- lecture seule pour le dashboard, y compris sur les tables créées plus tard par etl_writer
GRANT SELECT ON ALL TABLES IN SCHEMA dw TO dashboard_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE etl_writer IN SCHEMA dw GRANT SELECT ON TABLES TO dashboard_reader;
