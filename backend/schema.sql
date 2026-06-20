-- Care Package — MySQL schema (PHP 8.3 / MySQL on shared hosting)
-- Charset: utf8mb4. Designed for UK care homes with audit/CQC needs.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE IF NOT EXISTS companies (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  name            VARCHAR(160) NOT NULL,
  slug            VARCHAR(80) NOT NULL UNIQUE,
  contact_email   VARCHAR(160) NULL,
  cqc_provider_id VARCHAR(40) NULL,
  plan            VARCHAR(40) NOT NULL DEFAULT 'starter',
  status          VARCHAR(40) NOT NULL DEFAULT 'trial',
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS homes (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  company_id       INT NOT NULL,
  name             VARCHAR(160) NOT NULL,
  address          VARCHAR(255) NULL,
  lat              DECIMAL(10,7) NULL,
  lng              DECIMAL(10,7) NULL,
  cqc_location_id  VARCHAR(40) NULL,
  cqc_rating       VARCHAR(40) NULL,
  cqc_rating_date  DATE NULL,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (company_id) REFERENCES companies(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS staff (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  company_id       INT NOT NULL,
  home_id          INT NOT NULL,
  name             VARCHAR(120) NOT NULL,
  email            VARCHAR(160) NOT NULL UNIQUE,
  password_hash    VARCHAR(255) NOT NULL,
  role             ENUM('carer','seniorCarer','nurse','manager','admin') NOT NULL DEFAULT 'carer',
  pin_hash         VARCHAR(255) NULL,
  monitoring_competency TEXT NULL,
  supervision_notes TEXT NULL,
  competency_review_date DATE NULL,
  can_switch_homes TINYINT(1) NOT NULL DEFAULT 0,
  on_shift         TINYINT(1) NOT NULL DEFAULT 0,
  active           TINYINT(1) NOT NULL DEFAULT 1,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (company_id) REFERENCES companies(id),
  FOREIGN KEY (home_id) REFERENCES homes(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS residents (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  home_id       INT NOT NULL,
  first_name    VARCHAR(80) NOT NULL,
  last_name     VARCHAR(80) NOT NULL,
  dob           DATE NULL,
  room_number   VARCHAR(20) NULL,
  photo_url     VARCHAR(255) NULL,
  nhs_number    CHAR(10) NULL,
  care_level    ENUM('residential','nursing','dementia','respite','palliative','home_care') NOT NULL DEFAULT 'residential',
  address       TEXT NULL,
  call_frequency ENUM('daily','weekly') NOT NULL DEFAULT 'daily',
  call_times    TEXT NULL,
  conditions    TEXT NULL,        -- comma-separated or JSON
  allergies     TEXT NULL,
  medications   TEXT NULL,        -- required/prescribed medications, comma-separated
  monitoring_methods TEXT NULL,
  mobility      ENUM('independent','walking_aid','wheelchair','bedbound') NOT NULL DEFAULT 'independent',
  fall_risk     ENUM('low','medium','high') NOT NULL DEFAULT 'low',
  nutrition_risk ENUM('low','medium','high') NOT NULL DEFAULT 'low',
  dnacpr        TINYINT(1) NOT NULL DEFAULT 0,
  monitoring_consent ENUM('not_required','resident','representative','declined') NOT NULL DEFAULT 'not_required',
  consent_representative VARCHAR(120) NULL,
  consent_recorded_at DATE NULL,
  outcome_review_date DATE NULL,
  gp_name       VARCHAR(120) NULL,
  next_of_kin   VARCHAR(120) NULL,
  next_of_kin_phone VARCHAR(40) NULL,
  active        TINYINT(1) NOT NULL DEFAULT 1,
  processing_restricted TINYINT(1) NOT NULL DEFAULT 0,
  pseudonymised_at DATETIME NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (home_id) REFERENCES homes(id),
  INDEX (home_id, active)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vitals (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  resident_id      INT NOT NULL,
  recorded_by      INT NULL,
  recorded_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  respiratory_rate INT NULL,
  spo2             INT NULL,
  on_oxygen        TINYINT(1) NOT NULL DEFAULT 0,
  temperature      DECIMAL(4,1) NULL,
  systolic_bp      INT NULL,
  heart_rate       INT NULL,
  consciousness    ENUM('A','C','V','P','U') NOT NULL DEFAULT 'A',
  blood_glucose    DECIMAL(4,1) NULL,
  news2_score      INT NULL,
  notes            TEXT NULL,
  FOREIGN KEY (resident_id) REFERENCES residents(id),
  FOREIGN KEY (recorded_by) REFERENCES staff(id),
  INDEX (resident_id, recorded_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alerts (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  home_id         INT NOT NULL,
  resident_id     INT NULL,
  type            ENUM('fall','callBell','wandering','bedExit','chairExit',
                       'inactivity','vitalsDeterioration','medicationMissed',
                       'manual','doorContact','panicButton') NOT NULL,
  severity        ENUM('critical','high','medium','low','info') NOT NULL DEFAULT 'high',
  status          ENUM('active','acknowledged','resolved','escalated') NOT NULL DEFAULT 'active',
  location        VARCHAR(120) NULL,
  lat             DECIMAL(10,7) NULL,
  lng             DECIMAL(10,7) NULL,
  message         TEXT NULL,
  source          VARCHAR(80) NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  acknowledged_at DATETIME NULL,
  acknowledged_by INT NULL,
  resolved_at     DATETIME NULL,
  resolution_notes TEXT NULL,
  FOREIGN KEY (home_id) REFERENCES homes(id),
  FOREIGN KEY (resident_id) REFERENCES residents(id),
  INDEX (home_id, status, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS medications (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  resident_id     INT NOT NULL,
  name            VARCHAR(160) NOT NULL,
  dose            VARCHAR(60) NOT NULL,
  route           VARCHAR(40) NOT NULL DEFAULT 'oral',
  frequency       VARCHAR(80) NULL,
  times           VARCHAR(120) NULL,  -- comma-separated HH:MM
  prn             TINYINT(1) NOT NULL DEFAULT 0,
  prn_reason      VARCHAR(160) NULL,
  controlled_drug TINYINT(1) NOT NULL DEFAULT 0,
  start_date      DATE NULL,
  end_date        DATE NULL,
  instructions    TEXT NULL,
  active          TINYINT(1) NOT NULL DEFAULT 1,
  FOREIGN KEY (resident_id) REFERENCES residents(id),
  INDEX (resident_id, active)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mar_entries (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  medication_id   INT NOT NULL,
  resident_id     INT NOT NULL,
  scheduled_for   DATETIME NOT NULL,
  administered_at DATETIME NULL,
  administered_by INT NULL,
  outcome         ENUM('given','refused','omitted','unavailable','asleep','hospital') NOT NULL DEFAULT 'given',
  witness         VARCHAR(120) NULL,
  notes           TEXT NULL,
  FOREIGN KEY (medication_id) REFERENCES medications(id),
  FOREIGN KEY (resident_id) REFERENCES residents(id),
  INDEX (resident_id, scheduled_for)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS care_rounds (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  resident_id   INT NOT NULL,
  due_at        DATETIME NOT NULL,
  completed_at  DATETIME NULL,
  completed_by  INT NULL,
  type          ENUM('welfare','repositioning','continence','fluid','food','night') NOT NULL DEFAULT 'welfare',
  position      VARCHAR(40) NULL,
  observation   VARCHAR(120) NULL,
  skipped       TINYINT(1) NOT NULL DEFAULT 0,
  notes         TEXT NULL,
  FOREIGN KEY (resident_id) REFERENCES residents(id),
  INDEX (resident_id, due_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS care_calls (
  id                    INT AUTO_INCREMENT PRIMARY KEY,
  resident_id           INT NOT NULL,
  scheduled_date        DATE NOT NULL,
  scheduled_time        CHAR(5) NOT NULL,
  confirmed             TINYINT(1) NOT NULL DEFAULT 0,
  confirmed_at          DATETIME NULL,
  confirmed_by          INT NULL,
  notes                 TEXT NULL,
  care_provided         TEXT NULL,
  safety_checked        TINYINT(1) NOT NULL DEFAULT 0,
  wellbeing_status      ENUM('stable','physical_change','mental_change','both') NOT NULL DEFAULT 'stable',
  escalated_to          VARCHAR(120) NULL,
  promotes_independence TINYINT(1) NOT NULL DEFAULT 1,
  review_required       TINYINT(1) NOT NULL DEFAULT 0,
  created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (resident_id) REFERENCES residents(id),
  FOREIGN KEY (confirmed_by) REFERENCES staff(id),
  UNIQUE KEY uq_care_calls_schedule (resident_id, scheduled_date, scheduled_time),
  INDEX (resident_id, scheduled_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS incidents (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  resident_id     INT NOT NULL,
  category        VARCHAR(40) NOT NULL,
  severity        ENUM('minor','moderate','major','catastrophic') NOT NULL DEFAULT 'minor',
  occurred_at     DATETIME NOT NULL,
  reported_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reported_by     INT NULL,
  location        VARCHAR(120) NULL,
  description     TEXT NOT NULL,
  immediate_action TEXT NULL,
  injury          TINYINT(1) NOT NULL DEFAULT 0,
  injury_details  TEXT NULL,
  witnessed       TINYINT(1) NOT NULL DEFAULT 0,
  witnesses       VARCHAR(255) NULL,
  family_notified TINYINT(1) NOT NULL DEFAULT 0,
  gp_notified     TINYINT(1) NOT NULL DEFAULT 0,
  cqc_notifiable  TINYINT(1) NOT NULL DEFAULT 0,
  safeguarding    TINYINT(1) NOT NULL DEFAULT 0,
  photos          TEXT NULL,
  status          ENUM('open','investigating','closed') NOT NULL DEFAULT 'open',
  FOREIGN KEY (resident_id) REFERENCES residents(id),
  INDEX (resident_id, occurred_at)
) ENGINE=InnoDB;

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

-- Audit log for CQC / UK GDPR accountability.
CREATE TABLE IF NOT EXISTS audit_log (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  staff_id    INT NULL,
  home_id     INT NULL,
  action      VARCHAR(80) NOT NULL,
  entity      VARCHAR(40) NOT NULL,
  entity_id   INT NULL,
  ip_address  VARCHAR(45) NULL,
  before_json JSON NULL,
  after_json  JSON NULL,
  detail      TEXT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (entity, entity_id),
  INDEX (created_at)
) ENGINE=InnoDB;

-- Brute-force / rate-limit tracking (DB-backed, no Redis required).
CREATE TABLE IF NOT EXISTS auth_throttle (
  scope              VARCHAR(40)  NOT NULL,
  identifier         VARCHAR(255) NOT NULL,
  attempts           INT          NOT NULL DEFAULT 0,
  window_started_at  DATETIME     NOT NULL,
  locked_until       DATETIME     NULL,
  updated_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (scope, identifier)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS gdpr_requests (
  id           BIGINT AUTO_INCREMENT PRIMARY KEY,
  home_id      INT NOT NULL,
  resident_id  INT NOT NULL,
  type         ENUM('access','restriction','unrestriction','erasure') NOT NULL,
  performed_by INT NULL,
  detail       TEXT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (home_id) REFERENCES homes(id),
  FOREIGN KEY (resident_id) REFERENCES residents(id),
  FOREIGN KEY (performed_by) REFERENCES staff(id),
  INDEX (home_id, created_at),
  INDEX (resident_id, created_at)
) ENGINE=InnoDB;

