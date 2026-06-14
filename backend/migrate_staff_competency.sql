ALTER TABLE staff
  ADD COLUMN monitoring_competency TEXT NULL AFTER pin_hash,
  ADD COLUMN supervision_notes TEXT NULL AFTER monitoring_competency,
  ADD COLUMN competency_review_date DATE NULL AFTER supervision_notes;