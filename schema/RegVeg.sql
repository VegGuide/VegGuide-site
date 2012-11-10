CREATE TABLE `AddressFormat` (
  `address_format_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `format` varchar(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`address_format_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

CREATE TABLE `Attribute` (
  `attribute_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL DEFAULT '',
  PRIMARY KEY (`attribute_id`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=latin1;

CREATE TABLE `Category` (
  `category_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL DEFAULT '',
  `display_order` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`category_id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=latin1;

CREATE TABLE `Cuisine` (
  `cuisine_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(40) NOT NULL DEFAULT '',
  `parent_cuisine_id` int(11) unsigned DEFAULT NULL,
  PRIMARY KEY (`cuisine_id`),
  UNIQUE KEY `Cuisine___name` (`name`),
  KEY `Cuisine___parent_cuisine_id` (`parent_cuisine_id`)
) ENGINE=InnoDB AUTO_INCREMENT=72 DEFAULT CHARSET=latin1;

CREATE TABLE `Locale` (
  `locale_id` int(11) NOT NULL AUTO_INCREMENT,
  `locale_code` varchar(15) NOT NULL DEFAULT '',
  `address_format_id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `requires_localized_addresses` tinyint(1) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`locale_id`)
) ENGINE=InnoDB AUTO_INCREMENT=57 DEFAULT CHARSET=latin1;

CREATE TABLE `LocaleEncoding` (
  `locale_id` int(11) NOT NULL DEFAULT '0',
  `encoding_name` varchar(15) NOT NULL DEFAULT '',
  PRIMARY KEY (`locale_id`,`encoding_name`),
  KEY `LocaleEncoding___encoding_name` (`encoding_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `Location` (
  `location_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(200) NOT NULL DEFAULT '',
  `localized_name` varchar(200) DEFAULT NULL,
  `time_zone_name` varchar(100) DEFAULT NULL,
  `can_have_vendors` tinyint(1) NOT NULL DEFAULT '0',
  `is_country` tinyint(1) NOT NULL DEFAULT '0',
  `parent_location_id` int(11) unsigned DEFAULT NULL,
  `locale_id` int(11) DEFAULT NULL,
  `creation_datetime` datetime NOT NULL DEFAULT '2007-01-01 00:00:00',
  `user_id` int(11) unsigned NOT NULL DEFAULT '1',
  `has_addresses` tinyint(1) NOT NULL DEFAULT '1',
  `has_hours` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`location_id`),
  KEY `Location___name___parent_location_id` (`name`,`parent_location_id`),
  KEY `Location___locale_id` (`locale_id`),
  KEY `Location___parent_location_id` (`parent_location_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2203 DEFAULT CHARSET=latin1;

CREATE TABLE `LocationComment` (
  `location_id` int(11) unsigned NOT NULL DEFAULT '0',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0',
  `comment` text NOT NULL,
  `last_modified_datetime` datetime NOT NULL,
  PRIMARY KEY (`location_id`,`user_id`),
  KEY `LocationComment___user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `LocationOwner` (
  `location_id` int(11) unsigned NOT NULL DEFAULT '0',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`location_id`,`user_id`),
  KEY `LocationOwner___user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `NewsItem` (
  `item_id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(250) NOT NULL,
  `creation_datetime` datetime NOT NULL,
  `body` mediumtext NOT NULL,
  PRIMARY KEY (`item_id`)
) ENGINE=InnoDB AUTO_INCREMENT=92 DEFAULT CHARSET=latin1;

CREATE TABLE `PaymentOption` (
  `payment_option_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL DEFAULT '',
  PRIMARY KEY (`payment_option_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;

CREATE TABLE `PriceRange` (
  `price_range_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `description` varchar(30) NOT NULL,
  `display_order` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY (`price_range_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;

CREATE TABLE `Session` (
  `id` varchar(72) NOT NULL,
  `session_data` blob NOT NULL,
  `expires` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `SurveyResponse2008001` (
  `survey_response_id` int(11) NOT NULL AUTO_INCREMENT,
  `ip_address` varchar(15) NOT NULL,
  `visit_frequency` varchar(20) NOT NULL,
  `diet` varchar(15) NOT NULL,
  `browse_with_purpose` tinyint(1) NOT NULL DEFAULT '0',
  `browse_for_fun` tinyint(1) NOT NULL DEFAULT '0',
  `search_by_name` tinyint(1) NOT NULL DEFAULT '0',
  `search_by_address` tinyint(1) NOT NULL DEFAULT '0',
  `front_page_new_entries` tinyint(1) NOT NULL DEFAULT '0',
  `front_page_new_reviews` tinyint(1) NOT NULL DEFAULT '0',
  `rate_review` tinyint(1) NOT NULL DEFAULT '0',
  `add_entries` tinyint(1) NOT NULL DEFAULT '0',
  `just_restaurants` tinyint(1) NOT NULL DEFAULT '0',
  `listing_filter` tinyint(1) NOT NULL DEFAULT '0',
  `map_listings` tinyint(1) NOT NULL DEFAULT '0',
  `printable_listings` tinyint(1) NOT NULL DEFAULT '0',
  `watch_lists` tinyint(1) NOT NULL DEFAULT '0',
  `openid` tinyint(1) NOT NULL DEFAULT '0',
  `vegdining` tinyint(1) NOT NULL DEFAULT '0',
  `happycow` tinyint(1) NOT NULL DEFAULT '0',
  `citysearch` tinyint(1) NOT NULL DEFAULT '0',
  `yelp` tinyint(1) NOT NULL DEFAULT '0',
  `vegcity` tinyint(1) NOT NULL DEFAULT '0',
  `other_sites_other` mediumtext,
  `improvements` mediumtext,
  `email_address` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`survey_response_id`)
) ENGINE=InnoDB AUTO_INCREMENT=310 DEFAULT CHARSET=latin1;

CREATE TABLE `User` (
  `user_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `email_address` varchar(150) NOT NULL DEFAULT '',
  `password` varchar(40) NOT NULL DEFAULT '',
  `real_name` varchar(100) NOT NULL DEFAULT '',
  `home_page` varchar(150) DEFAULT NULL,
  `creation_datetime` datetime NOT NULL,
  `forgot_password_digest` varchar(40) DEFAULT NULL,
  `forgot_password_digest_datetime` datetime DEFAULT NULL,
  `is_admin` tinyint(1) unsigned NOT NULL DEFAULT '0',
  `allows_email` tinyint(1) NOT NULL DEFAULT '0',
  `team_id` int(11) DEFAULT NULL,
  `entries_per_page` int(11) NOT NULL DEFAULT '20',
  `openid_uri` varchar(255) DEFAULT NULL,
  `bio` mediumtext,
  `how_veg` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `image_extension` varchar(3) DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `User___email_address` (`email_address`),
  UNIQUE KEY `User___real_name` (`real_name`),
  UNIQUE KEY `User___openid_uri` (`openid_uri`)
) ENGINE=InnoDB AUTO_INCREMENT=8975 DEFAULT CHARSET=latin1;

CREATE TABLE `UserActivityLog` (
  `user_activity_log_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) unsigned NOT NULL DEFAULT '0',
  `user_activity_log_type_id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `activity_datetime` datetime NOT NULL,
  `comment` text,
  `vendor_id` int(11) unsigned DEFAULT NULL,
  `location_id` int(11) unsigned DEFAULT NULL,
  PRIMARY KEY (`user_activity_log_id`),
  KEY `UserActivityLog___user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=958001 DEFAULT CHARSET=latin1;

CREATE TABLE `UserActivityLogType` (
  `user_activity_log_type_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(30) NOT NULL DEFAULT '',
  PRIMARY KEY (`user_activity_log_type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=latin1;

CREATE TABLE `UserLocationSubscription` (
  `user_id` int(11) unsigned NOT NULL DEFAULT '0',
  `location_id` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`user_id`,`location_id`),
  KEY `UserLocationSubscription___location_id` (`location_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `Vendor` (
  `vendor_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL DEFAULT '',
  `localized_name` varchar(100) DEFAULT NULL,
  `short_description` varchar(250) NOT NULL DEFAULT '',
  `localized_short_description` varchar(250) DEFAULT NULL,
  `long_description` text,
  `address1` varchar(255) DEFAULT NULL,
  `localized_address1` varchar(255) DEFAULT NULL,
  `address2` varchar(255) DEFAULT NULL,
  `localized_address2` varchar(255) DEFAULT NULL,
  `neighborhood` varchar(250) DEFAULT NULL,
  `localized_neighborhood` varchar(250) DEFAULT NULL,
  `directions` mediumtext,
  `city` varchar(150) DEFAULT NULL,
  `localized_city` varchar(150) DEFAULT NULL,
  `region` varchar(100) DEFAULT NULL,
  `localized_region` varchar(100) DEFAULT NULL,
  `postal_code` varchar(30) DEFAULT NULL,
  `phone` varchar(25) DEFAULT NULL,
  `home_page` varchar(150) DEFAULT NULL,
  `veg_level` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `allows_smoking` tinyint(1) DEFAULT NULL,
  `is_wheelchair_accessible` tinyint(1) DEFAULT NULL,
  `accepts_reservations` tinyint(1) DEFAULT NULL,
  `creation_datetime` datetime NOT NULL,
  `last_modified_datetime` datetime NOT NULL,
  `last_featured_date` date DEFAULT NULL,
  `user_id` int(11) unsigned NOT NULL DEFAULT '0',
  `location_id` int(11) unsigned NOT NULL DEFAULT '0',
  `price_range_id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `localized_long_description` text,
  `latitude` float DEFAULT NULL,
  `longitude` float DEFAULT NULL,
  `is_cash_only` tinyint(1) NOT NULL DEFAULT '0',
  `close_date` date DEFAULT NULL,
  `canonical_address` mediumtext,
  `external_unique_id` varchar(255) DEFAULT NULL,
  `vendor_source_id` int(11) unsigned DEFAULT NULL,
  `sortable_name` varchar(255) NOT NULL,
  PRIMARY KEY (`vendor_id`),
  UNIQUE KEY `Vendor___external_unique_id___vendor_source_id` (`external_unique_id`,`vendor_source_id`),
  KEY `Vendor___location_id` (`location_id`),
  KEY `Vendor___postal_code___5` (`postal_code`(5)),
  KEY `Vendor___user_id` (`user_id`),
  KEY `Vendor___price_range_id` (`price_range_id`),
  KEY `Vendor___canonical_address___200` (`canonical_address`(200))
) ENGINE=InnoDB AUTO_INCREMENT=14226 DEFAULT CHARSET=latin1;

CREATE TABLE `VendorAttribute` (
  `vendor_id` int(11) unsigned NOT NULL DEFAULT '0',
  `attribute_id` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`vendor_id`,`attribute_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `VendorCategory` (
  `vendor_id` int(11) unsigned NOT NULL DEFAULT '0',
  `category_id` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`vendor_id`,`category_id`),
  KEY `VendorCategory___category_id` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `VendorComment` (
  `vendor_id` int(11) unsigned NOT NULL DEFAULT '0',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0',
  `comment` text,
  `last_modified_datetime` datetime NOT NULL,
  PRIMARY KEY (`vendor_id`,`user_id`),
  KEY `VendorComment___user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `VendorCuisine` (
  `vendor_id` int(11) unsigned NOT NULL DEFAULT '0',
  `cuisine_id` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`vendor_id`,`cuisine_id`),
  KEY `VendorCuisine___cuisine_id` (`cuisine_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `VendorHours` (
  `vendor_id` int(11) unsigned NOT NULL DEFAULT '0',
  `day` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `open_minute` int(11) NOT NULL DEFAULT '0',
  `close_minute` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`vendor_id`,`day`,`open_minute`,`close_minute`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `VendorImage` (
  `vendor_image_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `vendor_id` int(11) unsigned NOT NULL,
  `display_order` tinyint(3) unsigned NOT NULL,
  `extension` varchar(3) NOT NULL,
  `caption` mediumtext,
  `user_id` int(11) unsigned NOT NULL,
  PRIMARY KEY (`vendor_image_id`),
  KEY `VendorImage___vendor_id___display_order` (`vendor_id`,`display_order`)
) ENGINE=InnoDB AUTO_INCREMENT=5698 DEFAULT CHARSET=latin1;

CREATE TABLE `VendorPaymentOption` (
  `payment_option_id` int(11) unsigned NOT NULL DEFAULT '0',
  `vendor_id` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`payment_option_id`,`vendor_id`),
  KEY `VendorPaymentOption___vendor_id` (`vendor_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `VendorRating` (
  `vendor_id` int(11) unsigned NOT NULL DEFAULT '0',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0',
  `rating` tinyint(4) NOT NULL,
  `rating_datetime` datetime NOT NULL,
  PRIMARY KEY (`vendor_id`,`user_id`),
  KEY `VendorRating___user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `VendorSource` (
  `vendor_source_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `display_uri` varchar(255) NOT NULL,
  `feed_uri` varchar(255) NOT NULL,
  `filter_class` varchar(50) NOT NULL,
  `last_processed_datetime` datetime DEFAULT NULL,
  PRIMARY KEY (`vendor_source_id`),
  UNIQUE KEY `VendorSource___feed_uri` (`feed_uri`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=latin1;

CREATE TABLE `VendorSourceExcludedId` (
  `vendor_source_id` int(11) unsigned NOT NULL,
  `external_unique_id` varchar(255) NOT NULL,
  PRIMARY KEY (`vendor_source_id`,`external_unique_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `VendorSuggestion` (
  `vendor_suggestion_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(10) NOT NULL DEFAULT '',
  `suggestion` blob NOT NULL,
  `comment` text,
  `user_wants_notification` tinyint(1) NOT NULL DEFAULT '0',
  `creation_datetime` datetime NOT NULL,
  `vendor_id` int(11) unsigned NOT NULL DEFAULT '0',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`vendor_suggestion_id`),
  KEY `VendorSuggestion___user_id` (`user_id`),
  KEY `VendorSuggestion___vendor_id` (`vendor_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE AppliedMigration (
    migration  VARCHAR(250)  PRIMARY KEY
);

DROP FUNCTION IF EXISTS WEIGHTED_RATING;
delimiter //
CREATE FUNCTION
  WEIGHTED_RATING (vendor_id INTEGER, min INTEGER, overall_mean FLOAT)
                  RETURNS FLOAT
  DETERMINISTIC
  READS SQL DATA
BEGIN
  DECLARE v_mean FLOAT;
  DECLARE v_count FLOAT;
  DECLARE l_mean FLOAT;

  SELECT AVG(rating), COUNT(rating) INTO v_mean, v_count
    FROM VendorRating
   WHERE VendorRating.vendor_id = vendor_id;

  IF v_count = 0 THEN
    RETURN 0.0;
  END IF;

  RETURN ( v_count / ( v_count + min ) ) * v_mean + ( min / ( v_count + min ) ) * overall_mean;
END//

delimiter ;

DROP FUNCTION IF EXISTS GREAT_CIRCLE_DISTANCE;
delimiter //
CREATE FUNCTION
  GREAT_CIRCLE_DISTANCE ( radius DOUBLE,
                          v_lat DOUBLE, v_long DOUBLE,
                          p_lat DOUBLE, p_long DOUBLE )
                        RETURNS DOUBLE
  DETERMINISTIC
BEGIN

  RETURN (2
          * radius
          * ATAN2( SQRT( @x := ( POW( SIN( ( RADIANS(v_lat) - RADIANS(p_lat) ) / 2 ), 2 )
                                 + COS( RADIANS( p_lat ) ) * COS( RADIANS(v_lat) )
                                 * POW( SIN( ( RADIANS(v_long) - RADIANS(p_long) ) / 2 ), 2 )
                               )
                       ),
                   SQRT( 1 - @x ) )
         );
END//

delimiter ;

ALTER TABLE `Location`
  ADD FOREIGN KEY ( user_id )
  REFERENCES `User` ( user_id )
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

ALTER TABLE `Location`
  ADD FOREIGN KEY ( locale_id )
  REFERENCES `Locale` ( locale_id )
  ON DELETE SET NULL
  ON UPDATE CASCADE;

ALTER TABLE `Location`
  ADD FOREIGN KEY ( parent_location_id )
  REFERENCES `Location` ( location_id )
  ON DELETE SET NULL
  ON UPDATE CASCADE;

ALTER TABLE `LocationComment`
  ADD FOREIGN KEY ( user_id )
  REFERENCES `User` ( user_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `LocationComment`
  ADD FOREIGN KEY ( location_id )
  REFERENCES `Location` ( location_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `LocationOwner`
  ADD FOREIGN KEY ( user_id )
  REFERENCES `User` ( user_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `LocationOwner`
  ADD FOREIGN KEY ( location_id )
  REFERENCES `Location` ( location_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `Locale`
  ADD FOREIGN KEY ( address_format_id )
  REFERENCES `AddressFormat` ( address_format_id )
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

ALTER TABLE `LocaleEncoding`
  ADD FOREIGN KEY ( locale_id )
  REFERENCES `Locale` ( locale_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `Cuisine`
  ADD FOREIGN KEY ( parent_cuisine_id )
  REFERENCES `Cuisine` ( cuisine_id )
  ON DELETE SET NULL
  ON UPDATE CASCADE;

ALTER TABLE `Vendor`
  ADD FOREIGN KEY ( user_id )
  REFERENCES `User` ( user_id )
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

ALTER TABLE `Vendor`
  ADD FOREIGN KEY ( price_range_id )
  REFERENCES `PriceRange` ( price_range_id )
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

ALTER TABLE `Vendor`
  ADD FOREIGN KEY ( location_id )
  REFERENCES `Location` ( location_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `Vendor`
  ADD FOREIGN KEY ( vendor_source_id )
  REFERENCES `VendorSource` ( vendor_source_id )
  ON DELETE SET NULL
  ON UPDATE CASCADE;

ALTER TABLE `VendorHours`
  ADD FOREIGN KEY ( vendor_id )
  REFERENCES `Vendor` ( vendor_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorImage`
  ADD FOREIGN KEY ( user_id )
  REFERENCES `User` ( user_id )
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

ALTER TABLE `VendorImage`
  ADD FOREIGN KEY ( vendor_id )
  REFERENCES `Vendor` ( vendor_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorCuisine`
  ADD FOREIGN KEY ( cuisine_id )
  REFERENCES `Cuisine` ( cuisine_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorCuisine`
  ADD FOREIGN KEY ( vendor_id )
  REFERENCES `Vendor` ( vendor_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorComment`
  ADD FOREIGN KEY ( user_id )
  REFERENCES `User` ( user_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorComment`
  ADD FOREIGN KEY ( vendor_id )
  REFERENCES `Vendor` ( vendor_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorPaymentOption`
  ADD FOREIGN KEY ( vendor_id )
  REFERENCES `Vendor` ( vendor_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorPaymentOption`
  ADD FOREIGN KEY ( payment_option_id )
  REFERENCES `PaymentOption` ( payment_option_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorCategory`
  ADD FOREIGN KEY ( vendor_id )
  REFERENCES `Vendor` ( vendor_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorCategory`
  ADD FOREIGN KEY ( category_id )
  REFERENCES `Category` ( category_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorAttribute`
  ADD FOREIGN KEY ( attribute_id )
  REFERENCES `Attribute` ( attribute_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorAttribute`
  ADD FOREIGN KEY ( vendor_id )
  REFERENCES `Vendor` ( vendor_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorSourceExcludedId`
  ADD FOREIGN KEY ( vendor_source_id )
  REFERENCES `VendorSource` ( vendor_source_id )
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `VendorRating`
  ADD FOREIGN KEY ( user_id )
  REFERENCES `User` ( user_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorRating`
  ADD FOREIGN KEY ( vendor_id )
  REFERENCES `Vendor` ( vendor_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorSuggestion`
  ADD FOREIGN KEY ( user_id )
  REFERENCES `User` ( user_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `VendorSuggestion`
  ADD FOREIGN KEY ( vendor_id )
  REFERENCES `Vendor` ( vendor_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `UserLocationSubscription`
  ADD FOREIGN KEY ( user_id )
  REFERENCES `User` ( user_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `UserLocationSubscription`
  ADD FOREIGN KEY ( location_id )
  REFERENCES `Location` ( location_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `UserActivityLog`
  ADD FOREIGN KEY ( user_activity_log_type_id )
  REFERENCES `UserActivityLogType` ( user_activity_log_type_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `UserActivityLog`
  ADD FOREIGN KEY ( user_id )
  REFERENCES `User` ( user_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `UserActivityLog`
  ADD FOREIGN KEY ( location_id )
  REFERENCES `Location` ( location_id )
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE `UserActivityLog`
  ADD FOREIGN KEY ( vendor_id )
  REFERENCES `Vendor` ( vendor_id )
  ON DELETE SET NULL
  ON UPDATE CASCADE;

INSERT INTO UserActivityLogType (user_activity_log_type_id, type)
VALUES ( 1, 'add vendor'),
       ( 2, 'update vendor'),
       ( 3, 'suggest a change'),
       ( 4, 'suggestion accepted'),
       ( 5, 'suggestion rejected'),
       ( 6, 'add review'),
       ( 7, 'update review'),
       ( 8, 'delete review'),
       ( 9, 'add image'),
       (10, 'add region');

INSERT INTO AddressFormat (address_format_id, format)
VALUES (1, 'standard'), (2, 'Hungarian');

INSERT INTO Category (category_id, name, display_order)
VALUES ( 1, 'Restaurant',                  1 ),
       ( 2, 'Coffee/Tea/Juice',            2 ),
       ( 3, 'Bar',                         3 ),
       ( 4, 'Food Court or Street Vendor', 4 ),
       ( 5, 'Grocery/Bakery/Deli',         5 ),
       ( 6, 'Caterer',                     6 ),
       ( 7, 'General Store',               7 ),
       ( 8, 'Organization',                8 ),
       ( 9, 'Hotel/B&B',                   9 ),
       (10, 'Other',                      10 );

INSERT INTO PriceRange (price_range_id, description, display_order)
VALUES (1, '$ - inexpensive', 1),
       (2, '$$ - average',    2),
       (3, '$$$ - expensive', 3);
