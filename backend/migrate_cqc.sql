-- CQC migration — MySQL 5.7 compatible.
-- Run each block in phpMyAdmin (or via CLI). If a statement errors with
-- "Duplicate column name", that column already exists — skip it and continue.

SET NAMES utf8mb4;

-- ── 1. Companies table ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS companies (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  name            VARCHAR(160) NOT NULL,
  slug            VARCHAR(80) NOT NULL UNIQUE,
  contact_email   VARCHAR(160) NULL,
  cqc_provider_id VARCHAR(40) NULL,
  plan            VARCHAR(40) NOT NULL DEFAULT 'starter',
  status          VARCHAR(40) NOT NULL DEFAULT 'trial',
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ── 2. Seed a company row for existing installs (edit name/email to match yours)
INSERT IGNORE INTO companies (id, name, slug, contact_email, plan, status)
VALUES (1, 'My Care Organisation', 'my-care-org', '', 'starter', 'active');

-- ── 3. homes — each column in its own statement so one dupe won't block others
ALTER TABLE homes ADD COLUMN company_id      INT NOT NULL DEFAULT 1 AFTER id;
ALTER TABLE homes ADD COLUMN cqc_location_id VARCHAR(40) NULL;
ALTER TABLE homes ADD COLUMN cqc_rating      VARCHAR(40) NULL;
ALTER TABLE homes ADD COLUMN cqc_rating_date DATE NULL;

-- ── 4. staff — same pattern
ALTER TABLE staff ADD COLUMN company_id       INT NOT NULL DEFAULT 1 AFTER id;
ALTER TABLE staff ADD COLUMN can_switch_homes TINYINT(1) NOT NULL DEFAULT 0 AFTER pin_hash;

-- ── 5. Back-fill company_id on existing rows
UPDATE homes SET company_id = 1 WHERE company_id = 0;
UPDATE staff SET company_id = 1 WHERE company_id = 0;
