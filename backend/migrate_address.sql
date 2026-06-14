-- Add home address column for home care residents.
ALTER TABLE residents
  ADD COLUMN address TEXT NULL
    COMMENT 'Home address (used when care_level = home_care)'
  AFTER care_level;

ALTER TABLE residents
  MODIFY COLUMN care_level ENUM('residential','nursing','dementia','respite','palliative','home_care')
    NOT NULL DEFAULT 'residential';

ALTER TABLE residents
  ADD COLUMN call_frequency ENUM('daily','weekly') NOT NULL DEFAULT 'daily' AFTER address,
  ADD COLUMN call_times TEXT NULL AFTER call_frequency,
  ADD COLUMN monitoring_methods TEXT NULL AFTER medications,
  ADD COLUMN nutrition_risk ENUM('low','medium','high') NOT NULL DEFAULT 'low' AFTER fall_risk,
  ADD COLUMN monitoring_consent ENUM('not_required','resident','representative','declined')
    NOT NULL DEFAULT 'not_required' AFTER dnacpr,
  ADD COLUMN consent_representative VARCHAR(120) NULL AFTER monitoring_consent,
  ADD COLUMN consent_recorded_at DATE NULL AFTER consent_representative,
  ADD COLUMN outcome_review_date DATE NULL AFTER consent_recorded_at;
