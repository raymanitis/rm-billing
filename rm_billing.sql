-- RM Billing System Database Setup
-- This file should be imported into your database

CREATE TABLE IF NOT EXISTS `rm_invoices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `invoice_id` varchar(10) NOT NULL,
  `from_player` int(11) NOT NULL,
  `to_player` int(11) NOT NULL,
  `from_name` varchar(255) NOT NULL,
  `to_name` varchar(255) NOT NULL,
  `reason` text NOT NULL,
  `amount` int(11) NOT NULL,
  `status` enum('pending','paid','cancelled') NOT NULL DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `paid_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `invoice_id` (`invoice_id`),
  KEY `from_player` (`from_player`),
  KEY `to_player` (`to_player`),
  KEY `status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci; 