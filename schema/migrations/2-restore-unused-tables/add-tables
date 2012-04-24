CREATE TABLE `LocationEvent` (
  `uid` varchar(255) NOT NULL,
  `location_id` int(11) NOT NULL,
  `summary` mediumtext,
  `description` text,
  `url` varchar(255) DEFAULT NULL,
  `start_datetime` datetime NOT NULL,
  `end_datetime` datetime DEFAULT NULL,
  `is_all_day` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `LocationEventURI` (
  `location_id` int(11) NOT NULL,
  `uri` varchar(255) NOT NULL,
  PRIMARY KEY (`location_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `PersonalList` (
  `personal_list_id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL DEFAULT '0',
  `name` varchar(250) NOT NULL DEFAULT '',
  `is_public` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`personal_list_id`),
  UNIQUE KEY `PersonalList___user_id___name` (`user_id`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `PersonalListVendor` (
  `personal_list_id` int(11) NOT NULL DEFAULT '0',
  `vendor_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`personal_list_id`,`vendor_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE `Skin` (
  `skin_id` int(11) NOT NULL AUTO_INCREMENT,
  `hostname` varchar(50) NOT NULL DEFAULT '',
  `tagline` mediumtext,
  `owner_user_id` int(11) NOT NULL DEFAULT '0',
  `home_location_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`skin_id`),
  UNIQUE KEY `Skin___skin_id` (`skin_id`),
  KEY `Skin___owner_user_id` (`owner_user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=288 DEFAULT CHARSET=latin1;

CREATE TABLE `Team` (
  `team_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(250) NOT NULL DEFAULT '',
  `description` text NOT NULL,
  `home_page` varchar(250) DEFAULT NULL,
  `owner_user_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`team_id`),
  UNIQUE KEY `Team___owner_user_id` (`owner_user_id`),
  UNIQUE KEY `Team___name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

