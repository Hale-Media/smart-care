-- Add home address column for home care residents.
ALTER TABLE residents
  ADD COLUMN address TEXT NULL
    COMMENT 'Home address (used when care_level = home_care)'
  AFTER care_level;
