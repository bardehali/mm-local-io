-- MySQL dump 10.13  Distrib 8.0.19, for macos10.15 (x86_64)
--
-- Host: localhost    Database: shoppn_spree_development
-- ------------------------------------------------------
-- Server version	8.0.19

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `spree_zones`
--

DROP TABLE IF EXISTS `spree_zones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `spree_zones` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `default_tax` tinyint(1) DEFAULT '0',
  `zone_members_count` int DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `kind` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_spree_zones_on_default_tax` (`default_tax`),
  KEY `index_spree_zones_on_kind` (`kind`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `spree_zones`
--

LOCK TABLES `spree_zones` WRITE;
/*!40000 ALTER TABLE `spree_zones` DISABLE KEYS */;
INSERT INTO `spree_zones` (`id`, `name`, `description`, `default_tax`, `zone_members_count`, `created_at`, `updated_at`, `kind`) VALUES (1,'EU_VAT','Countries that make up the EU VAT zone.',0,28,'2020-06-24 19:58:04.942792','2020-06-24 19:58:04.942792','country'),(2,'North America','USA + Canada',0,2,'2020-06-24 19:58:04.957403','2020-06-24 19:58:04.957403','country'),(3,'South America','South America',0,14,'2020-06-24 19:58:04.965601','2020-06-24 19:58:04.965601','country'),(4,'Middle East','Middle East',0,16,'2020-06-24 19:58:04.973280','2020-06-24 19:58:04.973280','country'),(5,'Asia','Asia',0,52,'2020-06-24 19:58:04.979725','2020-06-24 19:58:04.979725','country'),(6,'California Tax','California tax zone',0,1,'2020-06-24 19:58:17.333683','2020-06-24 19:58:17.333683','state');
/*!40000 ALTER TABLE `spree_zones` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `spree_shipping_methods`
--

DROP TABLE IF EXISTS `spree_shipping_methods`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `spree_shipping_methods` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `display_on` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `tracking_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `admin_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tax_category_id` int DEFAULT NULL,
  `code` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `available_to_all` tinyint(1) DEFAULT '1',
  `available_to_users` tinyint(1) DEFAULT '1',
  `carrier` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `service_level` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `store_id` int DEFAULT NULL,
  `vendor_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_spree_shipping_methods_on_deleted_at` (`deleted_at`),
  KEY `index_spree_shipping_methods_on_tax_category_id` (`tax_category_id`),
  KEY `index_spree_shipping_methods_on_vendor_id` (`vendor_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `spree_shipping_methods`
--

LOCK TABLES `spree_shipping_methods` WRITE;
/*!40000 ALTER TABLE `spree_shipping_methods` DISABLE KEYS */;
INSERT INTO `spree_shipping_methods` (`id`, `name`, `display_on`, `deleted_at`, `created_at`, `updated_at`, `tracking_url`, `admin_name`, `tax_category_id`, `code`, `available_to_all`, `available_to_users`, `carrier`, `service_level`, `store_id`, `vendor_id`) VALUES (1,'UPS Ground (USD)','both',NULL,'2020-06-24 19:58:17.593511','2020-06-24 19:58:17.593511',NULL,NULL,NULL,NULL,1,1,NULL,NULL,NULL,NULL),(2,'UPS Two Day (USD)','both',NULL,'2020-06-24 19:58:17.615800','2020-06-24 19:58:17.615800',NULL,NULL,NULL,NULL,1,1,NULL,NULL,NULL,NULL),(3,'UPS One Day (USD)','both',NULL,'2020-06-24 19:58:17.638036','2020-06-24 19:58:17.638036',NULL,NULL,NULL,NULL,1,1,NULL,NULL,NULL,NULL),(4,'UPS Ground (EU)','both',NULL,'2020-06-24 19:58:17.660053','2020-06-24 19:58:17.660053',NULL,NULL,NULL,NULL,1,1,NULL,NULL,NULL,NULL),(5,'UPS Ground (EUR)','both',NULL,'2020-06-24 19:58:17.680992','2020-06-24 19:58:17.680992',NULL,NULL,NULL,NULL,1,1,NULL,NULL,NULL,NULL);
/*!40000 ALTER TABLE `spree_shipping_methods` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `spree_refund_reasons`
--

DROP TABLE IF EXISTS `spree_refund_reasons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `spree_refund_reasons` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `active` tinyint(1) DEFAULT '1',
  `mutable` tinyint(1) DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `code` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_spree_refund_reasons_on_lower_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `spree_refund_reasons`
--

LOCK TABLES `spree_refund_reasons` WRITE;
/*!40000 ALTER TABLE `spree_refund_reasons` DISABLE KEYS */;
INSERT INTO `spree_refund_reasons` (`id`, `name`, `active`, `mutable`, `created_at`, `updated_at`, `code`) VALUES (1,'Return processing',1,0,'2020-06-24 19:57:12.906250','2020-06-24 19:57:12.906250',NULL);
/*!40000 ALTER TABLE `spree_refund_reasons` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `spree_return_authorization_reasons`
--

DROP TABLE IF EXISTS `spree_return_authorization_reasons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `spree_return_authorization_reasons` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `active` tinyint(1) DEFAULT '1',
  `mutable` tinyint(1) DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_spree_return_authorization_reasons_on_lower_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `spree_return_authorization_reasons`
--

LOCK TABLES `spree_return_authorization_reasons` WRITE;
/*!40000 ALTER TABLE `spree_return_authorization_reasons` DISABLE KEYS */;
INSERT INTO `spree_return_authorization_reasons` (`id`, `name`, `active`, `mutable`, `created_at`, `updated_at`) VALUES (1,'Better price available',1,1,'2020-06-24 19:57:12.693944','2020-06-24 19:57:12.693944'),(2,'Missed estimated delivery date',1,1,'2020-06-24 19:57:12.698568','2020-06-24 19:57:12.698568'),(3,'Missing parts or accessories',1,1,'2020-06-24 19:57:12.703111','2020-06-24 19:57:12.703111'),(4,'Damaged/Defective',1,1,'2020-06-24 19:57:12.707531','2020-06-24 19:57:12.707531'),(5,'Different from what was ordered',1,1,'2020-06-24 19:57:12.711817','2020-06-24 19:57:12.711817'),(6,'Different from description',1,1,'2020-06-24 19:57:12.716181','2020-06-24 19:57:12.716181'),(7,'No longer needed/wanted',1,1,'2020-06-24 19:57:12.720671','2020-06-24 19:57:12.720671'),(8,'Accidental order',1,1,'2020-06-24 19:57:12.725258','2020-06-24 19:57:12.725258'),(9,'Unauthorized purchase',1,1,'2020-06-24 19:57:12.729980','2020-06-24 19:57:12.729980');
/*!40000 ALTER TABLE `spree_return_authorization_reasons` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `spree_tax_rates`
--

DROP TABLE IF EXISTS `spree_tax_rates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `spree_tax_rates` (
  `id` int NOT NULL AUTO_INCREMENT,
  `amount` decimal(8,5) DEFAULT NULL,
  `zone_id` int DEFAULT NULL,
  `tax_category_id` int DEFAULT NULL,
  `included_in_price` tinyint(1) DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `show_rate_in_label` tinyint(1) DEFAULT '1',
  `deleted_at` datetime DEFAULT NULL,
  `starts_at` datetime DEFAULT NULL,
  `expires_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_spree_tax_rates_on_deleted_at` (`deleted_at`),
  KEY `index_spree_tax_rates_on_included_in_price` (`included_in_price`),
  KEY `index_spree_tax_rates_on_show_rate_in_label` (`show_rate_in_label`),
  KEY `index_spree_tax_rates_on_tax_category_id` (`tax_category_id`),
  KEY `index_spree_tax_rates_on_zone_id` (`zone_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `spree_tax_rates`
--

LOCK TABLES `spree_tax_rates` WRITE;
/*!40000 ALTER TABLE `spree_tax_rates` DISABLE KEYS */;
INSERT INTO `spree_tax_rates` (`id`, `amount`, `zone_id`, `tax_category_id`, `included_in_price`, `created_at`, `updated_at`, `name`, `show_rate_in_label`, `deleted_at`, `starts_at`, `expires_at`) VALUES (1,0.10000,6,1,0,'2020-06-24 19:58:17.863503','2020-06-24 19:58:17.863503','California',1,NULL,NULL,NULL);
/*!40000 ALTER TABLE `spree_tax_rates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `spree_reimbursement_types`
--

DROP TABLE IF EXISTS `spree_reimbursement_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `spree_reimbursement_types` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `active` tinyint(1) DEFAULT '1',
  `mutable` tinyint(1) DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_spree_reimbursement_types_on_lower_name` (`name`),
  KEY `index_spree_reimbursement_types_on_type` (`type`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `spree_reimbursement_types`
--

LOCK TABLES `spree_reimbursement_types` WRITE;
/*!40000 ALTER TABLE `spree_reimbursement_types` DISABLE KEYS */;
INSERT INTO `spree_reimbursement_types` (`id`, `name`, `active`, `mutable`, `created_at`, `updated_at`, `type`) VALUES (1,'original',1,1,'2020-06-24 19:57:13.260959','2020-06-24 19:57:13.360361','Spree::ReimbursementType::OriginalPayment');
/*!40000 ALTER TABLE `spree_reimbursement_types` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2020-07-28 22:26:33
