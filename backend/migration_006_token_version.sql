-- =====================================================================
-- Smart Care — Migration 006
-- Add token_version to staff for instant session revocation.
-- Once deployed, every existing staff member starts at version 1;
-- login.php stamps tv=1 into the first new token.
-- =====================================================================

ALTER TABLE `staff`
  ADD COLUMN `token_version` INT NOT NULL DEFAULT 1 AFTER `active`;
-- End of migration 006
