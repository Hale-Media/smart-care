-- Smart Care — care plans + risk assessments migration
-- Run once against seanstua_care. Plain MySQL 5.7+ syntax (no MariaDB extensions).

SET NAMES utf8mb4;

-- ── 1. Extend audit_log with richer before/after columns ─────────────────────
-- Run each line separately if you need to re-run; plain ADD COLUMN errors if
-- the column already exists, so only run this block once.
ALTER TABLE audit_log
  ADD COLUMN home_id     INT NULL     AFTER staff_id,
  ADD COLUMN before_json LONGTEXT NULL AFTER detail,
  ADD COLUMN after_json  LONGTEXT NULL AFTER before_json;

-- ── 2. Care plan sections ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS care_plan_sections (
  id                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  home_id            INT UNSIGNED NOT NULL,
  resident_id        INT UNSIGNED NOT NULL,
  domain             VARCHAR(32)  NOT NULL,
  title              VARCHAR(160) NOT NULL,
  what_matters_to_me TEXT         NULL,
  how_to_support_me  TEXT         NOT NULL,
  goals              TEXT         NULL,
  agreed_with        VARCHAR(160) NULL,
  version_no         INT UNSIGNED NOT NULL DEFAULT 1,
  supersedes_id      INT UNSIGNED NULL,
  status             VARCHAR(16)  NOT NULL DEFAULT 'active',
  effective_from     DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  effective_to       DATETIME(3)  NULL,
  review_due         DATE         NULL,
  created_at         DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  created_by         INT UNSIGNED NOT NULL,
  updated_at         DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  updated_by         INT UNSIGNED NULL,
  deleted_at         DATETIME(3)  NULL,
  deleted_by         INT UNSIGNED NULL,
  row_version        INT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY idx_cps_resident_active (resident_id, status),
  KEY idx_cps_review (home_id, review_due)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── 3. Risk assessments ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS risk_assessments (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  home_id         INT UNSIGNED NOT NULL,
  resident_id     INT UNSIGNED NOT NULL,
  type            VARCHAR(32)  NOT NULL,
  tool_version    VARCHAR(16)  NULL,
  total_score     INT          NULL,
  risk_level      VARCHAR(16)  NOT NULL,
  detail          LONGTEXT     NULL,
  summary         TEXT         NULL,
  assessed_at     DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  assessed_by     INT UNSIGNED NOT NULL,
  review_due      DATE         NULL,
  version_no      INT UNSIGNED NOT NULL DEFAULT 1,
  supersedes_id   INT UNSIGNED NULL,
  status          VARCHAR(16)  NOT NULL DEFAULT 'active',
  created_at      DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  created_by      INT UNSIGNED NOT NULL,
  updated_at      DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  updated_by      INT UNSIGNED NULL,
  deleted_at      DATETIME(3)  NULL,
  deleted_by      INT UNSIGNED NULL,
  row_version     INT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY idx_ra_resident_type (resident_id, type, status),
  KEY idx_ra_review (home_id, review_due)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── 4. Care interventions ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS care_interventions (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  home_id             INT UNSIGNED NOT NULL,
  resident_id         INT UNSIGNED NOT NULL,
  section_id          INT UNSIGNED NOT NULL,
  risk_assessment_id  INT UNSIGNED NULL,
  description         VARCHAR(255) NOT NULL,
  frequency           VARCHAR(64)  NULL,
  status              VARCHAR(16)  NOT NULL DEFAULT 'active',
  created_at          DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  created_by          INT UNSIGNED NOT NULL,
  updated_at          DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  updated_by          INT UNSIGNED NULL,
  deleted_at          DATETIME(3)  NULL,
  deleted_by          INT UNSIGNED NULL,
  row_version         INT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY idx_ci_resident (resident_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── 5. Link existing tables ───────────────────────────────────────────────────
ALTER TABLE care_rounds
  ADD COLUMN care_intervention_id INT UNSIGNED NULL AFTER resident_id;

ALTER TABLE incidents
  ADD COLUMN risk_assessment_id INT UNSIGNED NULL AFTER resident_id;
