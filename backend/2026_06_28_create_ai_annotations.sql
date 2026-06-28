-- =============================================================================
--  Smart Care · AI layer · Phase 1 migration
--  ADDITIVE ONLY. Creates one new table; touches nothing existing. Safe to drop
--  cleanly if a test goes wrong:  DROP TABLE ai_annotations;
-- -----------------------------------------------------------------------------
--  Polymorphic by design: keyed on (entity, entity_id) to mirror the existing
--  audit_log convention, so one table annotates care_calls, handover_notes and
--  incidents alike. home_id is denormalised on here (resolved server-side at
--  write time from the entity's owning resident/home) so the review queue can
--  be tenant-scoped with a single indexed lookup.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `ai_annotations` (
  `id`            int(11) NOT NULL AUTO_INCREMENT,
  `home_id`       int(11) NOT NULL,
  `entity`        varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL
                    COMMENT 'care_call | handover_note | incident',
  `entity_id`     int(11) NOT NULL,
  `ai_summary`    text COLLATE utf8mb4_unicode_ci,
  `ai_risk_flags` json DEFAULT NULL COMMENT 'array of short strings',
  `ai_mood`       varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ai_follow_up`  tinyint(1) NOT NULL DEFAULT '0',
  `model_name`    varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `model_sha256`  char(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL
                    COMMENT 'weights provenance; matches PDF audit footer',
  `review_state`  enum('pending','confirmed','dismissed') COLLATE utf8mb4_unicode_ci
                    NOT NULL DEFAULT 'pending',
  `reviewed_by`   int(11) DEFAULT NULL,
  `reviewed_at`   datetime DEFAULT NULL,
  `created_at`    datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_entity` (`entity`, `entity_id`),
  KEY `idx_home_state` (`home_id`, `review_state`),
  KEY `idx_reviewed_by` (`reviewed_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Note: no FK constraints because entity_id points at different tables by
-- entity value. Referential integrity is enforced in the endpoint (the entity
-- must resolve to a real row in the caller's home, or the write is rejected).
