-- Add required medications column to residents table.
ALTER TABLE residents
  ADD COLUMN medications TEXT NULL
    COMMENT 'Required/prescribed medications, comma-separated'
  AFTER allergies;
