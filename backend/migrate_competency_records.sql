CREATE TABLE IF NOT EXISTS staff_competency_records (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  staff_id        INT NOT NULL,
  competency      VARCHAR(120) NOT NULL,
  assessed_date   DATE NOT NULL,
  expiry_date     DATE NULL,
  assessed_by     VARCHAR(120) NOT NULL,
  outcome         ENUM('passed','failed','pending') NOT NULL DEFAULT 'passed',
  notes           TEXT NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE,
  INDEX (staff_id, expiry_date)
) ENGINE=InnoDB;
