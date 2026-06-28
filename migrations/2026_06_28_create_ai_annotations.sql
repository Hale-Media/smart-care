-- Smart Care · Phase 1 AI layer
-- Additive-only: one new table, no changes to existing tables.
-- Safe to run repeatedly (IF NOT EXISTS).

CREATE TABLE IF NOT EXISTS ai_annotations (
  id            BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  home_id       INT               NOT NULL,
  entity        VARCHAR(30)       NOT NULL,   -- 'care_call' | 'handover_note' | 'incident'
  entity_id     INT               NOT NULL,
  ai_summary    TEXT,
  ai_risk_flags JSON,                         -- JSON array of flag strings
  ai_mood       VARCHAR(40),
  ai_follow_up  TINYINT(1)        NOT NULL DEFAULT 0,
  model_name    VARCHAR(120),
  model_sha256  CHAR(64),                     -- SHA-256 hex for provenance / PDF footer
  review_state  ENUM('pending','confirmed','dismissed') NOT NULL DEFAULT 'pending',
  reviewed_by   INT,                          -- staff.id of the senior reviewer
  reviewed_at   DATETIME,
  created_at    DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (id),
  -- One annotation per entity; ON DUPLICATE KEY UPDATE in ai_annotation_upsert.php
  UNIQUE KEY uq_entity (entity, entity_id),
  -- Review-queue filter: home + state
  INDEX idx_home_state   (home_id, review_state),
  -- Review-queue ordering: follow-up priority then recency
  INDEX idx_home_followup (home_id, ai_follow_up, created_at)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
