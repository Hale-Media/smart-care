CREATE TABLE IF NOT EXISTS handover_notes (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  home_id    INT NOT NULL,
  staff_id   INT NULL,
  shift      ENUM('am','pm','night') NOT NULL DEFAULT 'am',
  content    TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (home_id) REFERENCES homes(id),
  FOREIGN KEY (staff_id) REFERENCES staff(id),
  INDEX (home_id, created_at)
) ENGINE=InnoDB;
