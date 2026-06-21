-- Smart Care — Legal compliance tables (DoLS, LPA, Advance Decisions, Capacity Assessments)
-- Run once against seanstua_care. Plain MySQL 5.7+ syntax.

SET NAMES utf8mb4;

-- Drop existing tables if they exist (from a previous attempt)
DROP TABLE IF EXISTS capacity_assessments;
DROP TABLE IF EXISTS advance_decisions;
DROP TABLE IF EXISTS lasting_powers;
DROP TABLE IF EXISTS dols_authorisations;

-- ── 1. Deprivation of Liberty Safeguards (DoLS) ──────────────────────────────
CREATE TABLE IF NOT EXISTS dols_authorisations (
  id                INT NOT NULL AUTO_INCREMENT,
  home_id           INT NOT NULL,
  resident_id       INT NOT NULL,
  status            VARCHAR(32)  NOT NULL,
  urgent            TINYINT(1)   NOT NULL DEFAULT 0,
  reference         VARCHAR(160) NULL,
  supervisory_body  VARCHAR(160) NULL,
  applied_on        DATE         NULL,
  granted_on        DATE         NULL,
  expires_on        DATE         NULL,
  conditions        TEXT         NULL,
  notes             TEXT         NULL,
  recorded_by       INT NOT NULL,
  created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at        DATETIME     NULL,
  PRIMARY KEY (id),
  KEY idx_dols_resident (resident_id, deleted_at),
  KEY idx_dols_expiring (home_id, status, expires_on)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── 2. Lasting Powers of Attorney (LPA) ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS lasting_powers (
  id                INT NOT NULL AUTO_INCREMENT,
  home_id           INT NOT NULL,
  resident_id       INT NOT NULL,
  type              VARCHAR(32)  NOT NULL,
  attorney_name     VARCHAR(160) NOT NULL,
  attorney_contact  VARCHAR(160) NULL,
  registered        TINYINT(1)   NOT NULL DEFAULT 0,
  reference         VARCHAR(160) NULL,
  notes             TEXT         NULL,
  recorded_by       INT NOT NULL,
  created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at        DATETIME     NULL,
  PRIMARY KEY (id),
  KEY idx_lp_resident (resident_id, deleted_at),
  KEY idx_lp_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── 3. Advance Decisions (DNACPR, ReSPECT, ADRT) ──────────────────────────────
CREATE TABLE IF NOT EXISTS advance_decisions (
  id                INT NOT NULL AUTO_INCREMENT,
  home_id           INT NOT NULL,
  resident_id       INT NOT NULL,
  type              VARCHAR(32)  NOT NULL,
  in_place          TINYINT(1)   NOT NULL DEFAULT 1,
  form_reference    VARCHAR(160) NULL,
  completed_by      VARCHAR(160) NULL,
  date_completed    DATE         NULL,
  review_date       DATE         NULL,
  location          VARCHAR(160) NULL,
  notes             TEXT         NULL,
  recorded_by       INT NOT NULL,
  created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at        DATETIME     NULL,
  PRIMARY KEY (id),
  KEY idx_ad_resident (resident_id, deleted_at),
  KEY idx_ad_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── 4. Capacity Assessments (Mental Capacity Act) ────────────────────────────
CREATE TABLE IF NOT EXISTS capacity_assessments (
  id                    INT NOT NULL AUTO_INCREMENT,
  home_id               INT NOT NULL,
  resident_id           INT NOT NULL,
  decision              VARCHAR(160) NOT NULL,
  has_capacity          TINYINT(1)   NOT NULL,
  assessment_summary    TEXT         NULL,
  best_interests        TEXT         NULL,
  assessed_by           INT NOT NULL,
  review_due            DATE         NULL,
  version_no            INT NOT NULL DEFAULT 1,
  status                VARCHAR(16)  NOT NULL DEFAULT 'active',
  supersedes_id         INT NULL,
  created_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at            DATETIME     NULL,
  PRIMARY KEY (id),
  KEY idx_ca_resident (resident_id, status, deleted_at),
  KEY idx_ca_decision (decision, status),
  KEY idx_ca_review (home_id, review_due)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── 5. Audit log updates (MySQL 5.7 compatible - run only if columns don't exist) ────
-- If these columns already exist, skip this section or comment it out.
-- ALTER TABLE audit_log ADD COLUMN home_id INT NULL AFTER staff_id;
-- ALTER TABLE audit_log ADD COLUMN before_json LONGTEXT NULL AFTER detail;
-- ALTER TABLE audit_log ADD COLUMN after_json LONGTEXT NULL AFTER before_json;
