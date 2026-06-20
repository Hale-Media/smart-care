-- =====================================================================
-- Smart Care — Migration 003
-- Consent & legal layer: MCA capacity, DoLS, advance decisions,
-- lasting powers, and the safeguarding workflow.
-- Target: MySQL 5.7.44 (seanstua_care). Back up first; DDL auto-commits.
--
-- NOTE on DoLS vs LPS (current as of 2026): DoLS is still the operative
-- framework — LPS is in consultation and not before 2027. The dols_
-- authorisations table is built for DoLS but the columns are generic
-- enough that an LPS migration later is mostly a relabelling exercise.
-- =====================================================================


-- ---------------------------------------------------------------------
-- A. MCA capacity assessments (decision-specific, versioned)
-- Capacity is assessed per decision and can change, so re-assessment
-- supersedes (new version, old kept) — same pattern as risk_assessments.
-- ---------------------------------------------------------------------
CREATE TABLE `capacity_assessments` (
  `id`                  int(11) NOT NULL AUTO_INCREMENT,
  `home_id`             int(11) NOT NULL,
  `resident_id`         int(11) NOT NULL,
  `decision`            varchar(255) NOT NULL,   -- the specific decision assessed
  `has_capacity`        tinyint(1) NOT NULL,
  `assessment_summary`  text,                    -- how the conclusion was reached
  `best_interests`      text,                    -- if lacks capacity: the BI decision
  `assessed_by`         int(11) DEFAULT NULL,
  `assessed_at`         datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `review_due`          date DEFAULT NULL,
  `version_no`          int(10) unsigned NOT NULL DEFAULT 1,
  `supersedes_id`       int(11) DEFAULT NULL,
  `status`              enum('active','superseded') NOT NULL DEFAULT 'active',
  `created_at`          datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at`          datetime DEFAULT NULL,
  `deleted_by`          int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_ca_resident_status` (`resident_id`,`status`),
  KEY `idx_ca_review` (`home_id`,`review_due`),
  KEY `idx_ca_supersedes` (`supersedes_id`),
  CONSTRAINT `fk_ca_home`        FOREIGN KEY (`home_id`)       REFERENCES `homes` (`id`),
  CONSTRAINT `fk_ca_resident`    FOREIGN KEY (`resident_id`)   REFERENCES `residents` (`id`),
  CONSTRAINT `fk_ca_assessed_by` FOREIGN KEY (`assessed_by`)   REFERENCES `staff` (`id`),
  CONSTRAINT `fk_ca_supersedes`  FOREIGN KEY (`supersedes_id`) REFERENCES `capacity_assessments` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
-- B. DoLS authorisations (lifecycle + annual expiry)
-- expires_on is the field that matters — a DoLS lasts max 12 months and
-- must be renewed. It feeds the compliance dashboard's expiry warnings.
-- ---------------------------------------------------------------------
CREATE TABLE `dols_authorisations` (
  `id`                int(11) NOT NULL AUTO_INCREMENT,
  `home_id`           int(11) NOT NULL,
  `resident_id`       int(11) NOT NULL,
  `status`            enum('not_required','urgent','applied','granted','declined','expired','ended') NOT NULL DEFAULT 'applied',
  `urgent`            tinyint(1) NOT NULL DEFAULT 0,
  `reference`         varchar(80) DEFAULT NULL,   -- supervisory body's reference
  `supervisory_body`  varchar(160) DEFAULT NULL,  -- the local authority
  `applied_on`        date DEFAULT NULL,
  `granted_on`        date DEFAULT NULL,
  `expires_on`        date DEFAULT NULL,
  `conditions`        text,
  `notes`             text,
  `recorded_by`       int(11) DEFAULT NULL,
  `created_at`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by`        int(11) DEFAULT NULL,
  `deleted_at`        datetime DEFAULT NULL,
  `deleted_by`        int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_dols_resident` (`resident_id`,`status`),
  KEY `idx_dols_expiry` (`home_id`,`expires_on`),
  CONSTRAINT `fk_dols_home`     FOREIGN KEY (`home_id`)     REFERENCES `homes` (`id`),
  CONSTRAINT `fk_dols_resident` FOREIGN KEY (`resident_id`) REFERENCES `residents` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
-- C. Advance decisions (DNACPR / ReSPECT / ADRT)
-- Replaces the flat residents.dnacpr flag with a proper record. Leave
-- the old flag in place for now; migrate/retire it later.
-- ---------------------------------------------------------------------
CREATE TABLE `advance_decisions` (
  `id`             int(11) NOT NULL AUTO_INCREMENT,
  `home_id`        int(11) NOT NULL,
  `resident_id`    int(11) NOT NULL,
  `type`           enum('dnacpr','respect','adrt') NOT NULL,
  `in_place`       tinyint(1) NOT NULL DEFAULT 1,
  `form_reference` varchar(80) DEFAULT NULL,
  `completed_by`   varchar(160) DEFAULT NULL,  -- clinician who signed it
  `date_completed` date DEFAULT NULL,
  `review_date`    date DEFAULT NULL,
  `location`       varchar(160) DEFAULT NULL,  -- where the physical form is kept
  `notes`          text,
  `recorded_by`    int(11) DEFAULT NULL,
  `created_at`     datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by`     int(11) DEFAULT NULL,
  `deleted_at`     datetime DEFAULT NULL,
  `deleted_by`     int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_ad_resident` (`resident_id`,`type`),
  KEY `idx_ad_review` (`home_id`,`review_date`),
  CONSTRAINT `fk_ad_home`     FOREIGN KEY (`home_id`)     REFERENCES `homes` (`id`),
  CONSTRAINT `fk_ad_resident` FOREIGN KEY (`resident_id`) REFERENCES `residents` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
-- D. Lasting powers (LPA / deputy / appointee)
-- An LPA is only valid once registered with the OPG — hence `registered`.
-- ---------------------------------------------------------------------
CREATE TABLE `lasting_powers` (
  `id`               int(11) NOT NULL AUTO_INCREMENT,
  `home_id`          int(11) NOT NULL,
  `resident_id`      int(11) NOT NULL,
  `type`             enum('lpa_health','lpa_property','deputy','appointee') NOT NULL,
  `attorney_name`    varchar(160) NOT NULL,
  `attorney_contact` varchar(160) DEFAULT NULL,
  `registered`       tinyint(1) NOT NULL DEFAULT 0,  -- registered with OPG?
  `reference`        varchar(80) DEFAULT NULL,       -- OPG reference
  `notes`            text,
  `recorded_by`      int(11) DEFAULT NULL,
  `created_at`       datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`       datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by`       int(11) DEFAULT NULL,
  `deleted_at`       datetime DEFAULT NULL,
  `deleted_by`       int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_lp_resident` (`resident_id`,`type`),
  CONSTRAINT `fk_lp_home`     FOREIGN KEY (`home_id`)     REFERENCES `homes` (`id`),
  CONSTRAINT `fk_lp_resident` FOREIGN KEY (`resident_id`) REFERENCES `residents` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
-- E. Safeguarding concerns (workflow — distinct from incidents)
-- Lifecycle: raised -> under_review -> referred / no_referral -> closed.
-- Category uses the Care Act 2014 abuse types.
-- ---------------------------------------------------------------------
CREATE TABLE `safeguarding_concerns` (
  `id`                int(11) NOT NULL AUTO_INCREMENT,
  `home_id`           int(11) NOT NULL,
  `resident_id`       int(11) DEFAULT NULL,    -- NULL = home-wide / org concern
  `category`          enum('physical','psychological','financial','neglect','sexual',
                           'discriminatory','organisational','domestic','modern_slavery',
                           'self_neglect') NOT NULL,
  `description`       text NOT NULL,
  `status`            enum('raised','under_review','referred','no_referral','closed') NOT NULL DEFAULT 'raised',
  `linked_incident_id` int(11) DEFAULT NULL,
  -- raised
  `raised_by`         int(11) DEFAULT NULL,
  `raised_at`         datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- manager review
  `manager_review`    text,
  `reviewed_by`       int(11) DEFAULT NULL,
  `reviewed_at`       datetime DEFAULT NULL,
  -- local-authority referral
  `la_referred`       tinyint(1) NOT NULL DEFAULT 0,
  `la_reference`      varchar(80) DEFAULT NULL,
  `referred_at`       datetime DEFAULT NULL,
  `referred_by`       int(11) DEFAULT NULL,
  `cqc_notified`      tinyint(1) NOT NULL DEFAULT 0,
  -- outcome
  `outcome`           text,
  `closed_by`         int(11) DEFAULT NULL,
  `closed_at`         datetime DEFAULT NULL,
  -- conventions
  `updated_at`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by`        int(11) DEFAULT NULL,
  `deleted_at`        datetime DEFAULT NULL,
  `deleted_by`        int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_sg_home_status` (`home_id`,`status`),
  KEY `idx_sg_resident` (`resident_id`),
  KEY `idx_sg_incident` (`linked_incident_id`),
  CONSTRAINT `fk_sg_home`     FOREIGN KEY (`home_id`)            REFERENCES `homes` (`id`),
  CONSTRAINT `fk_sg_resident` FOREIGN KEY (`resident_id`)        REFERENCES `residents` (`id`),
  CONSTRAINT `fk_sg_incident` FOREIGN KEY (`linked_incident_id`) REFERENCES `incidents` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
-- F. UK GDPR data-subject rights support
-- ---------------------------------------------------------------------
ALTER TABLE `residents`
  ADD COLUMN `processing_restricted` tinyint(1) NOT NULL DEFAULT 0 AFTER `active`,
  ADD COLUMN `pseudonymised_at` datetime DEFAULT NULL AFTER `processing_restricted`;

CREATE TABLE `gdpr_requests` (
  `id`           bigint NOT NULL AUTO_INCREMENT,
  `home_id`      int(11) NOT NULL,
  `resident_id`  int(11) NOT NULL,
  `type`         enum('access','restriction','unrestriction','erasure') NOT NULL,
  `performed_by` int(11) DEFAULT NULL,
  `detail`       text,
  `created_at`   datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gdpr_home_created` (`home_id`,`created_at`),
  KEY `idx_gdpr_resident_created` (`resident_id`,`created_at`),
  CONSTRAINT `fk_gdpr_home`      FOREIGN KEY (`home_id`)      REFERENCES `homes` (`id`),
  CONSTRAINT `fk_gdpr_resident`  FOREIGN KEY (`resident_id`)  REFERENCES `residents` (`id`),
  CONSTRAINT `fk_gdpr_performed` FOREIGN KEY (`performed_by`) REFERENCES `staff` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- End of migration 003

