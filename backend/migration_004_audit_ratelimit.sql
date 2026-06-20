-- =====================================================================
-- Smart Care — Migration 004
-- audit_log columns (home_id, before_json, after_json) already exist.
-- Only the auth_throttle table needs creating.
-- =====================================================================

CREATE TABLE IF NOT EXISTS `auth_throttle` (
  `scope`             VARCHAR(40)  NOT NULL,
  `identifier`        VARCHAR(255) NOT NULL,
  `attempts`          INT          NOT NULL DEFAULT 0,
  `window_started_at` DATETIME     NOT NULL,
  `locked_until`      DATETIME     NULL,
  `updated_at`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`scope`, `identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- End of migration 004
