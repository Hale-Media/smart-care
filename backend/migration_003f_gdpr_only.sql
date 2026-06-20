-- Migration 003F — remaining GDPR pieces only.
-- processing_restricted already exists; this adds pseudonymised_at and gdpr_requests.
-- If pseudonymised_at also already exists you'll get a duplicate-column error — skip it.

ALTER TABLE `residents`
  ADD COLUMN `pseudonymised_at` datetime DEFAULT NULL AFTER `processing_restricted`;

CREATE TABLE IF NOT EXISTS `gdpr_requests` (
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
