SET CLIENT_MIN_MESSAGES = ERROR;

CREATE DOMAIN email_address AS citext
       CONSTRAINT valid_email_address CHECK ( VALUE ~ E'^.+@.+(?:\\..+)+' );

CREATE DOMAIN uri AS TEXT
       CONSTRAINT valid_uri CHECK ( VALUE ~ E'^https?://[\\w-_]+(\.[\\w-_]+)*\\.\\w{2,3}' );

CREATE "User" (
  user_id          BIGSERIAL         NOT NULL  PRIMARY KEY,
  email_address    email_address     NOT NULL  UNIQUE,
  password         VARCHAR(40)       NOT NULL,
  display_name     VARCHAR(100)      NOT NULL  UNIQUE,
  website          uri               NULL,
  is_admin         BOOL              DEFAULT FALSE NOT NULL,
  allows_email     BOOL              DEFAULT FALSE NOT NULL,
  entries_per_page BIGINT            DEFAULT 20 NOT NULL,
  bio              TEXT,
  how_veg          SMALLINT          NOT NULL,
  image_extension  VARCHAR(3)        NULL,
  forgot_password_digest VARCHAR(40) NULL,
  forgot_password_digest_datetime TIMESTAMP WITHOUT TIME ZONE NULL,
  creation_datetime TIMESTAMP WITHOUT TIME ZONE  NOT NULL,
  CONSTRAINT valid_display_name CHECK (display_name != '')
);

CREATE TABLE "Region" (
  region_id BIGSERIAL NOT NULL,
  name VARCHAR(200) DEFAULT '' NOT NULL,
  localized_name VARCHAR(200) DEFAULT NULL,
  time_zone_name VARCHAR(100) DEFAULT NULL,
  can_have_vendors BOOL DEFAULT FALSE NOT NULL,
  is_country BOOL DEFAULT FALSE NOT NULL,
  parent_location_id INTEGER DEFAULT NULL,
  locale_id BIGINT DEFAULT NULL,
  creation_datetime timestamp DEFAULT '2007-01-01 00:00:00' NOT NULL,
  user_id BIGINT DEFAULT 1 NOT NULL,
  has_addresses BOOL DEFAULT TRUE NOT NULL,
  has_hours BOOL DEFAULT TRUE NOT NULL,
  PRIMARY KEY ("location_id")
);



CREATE TABLE "AddressFormat" (
  address_format_id SERIAL NOT NULL,
  format VARCHAR(100) DEFAULT '' NOT NULL,
  PRIMARY KEY ("address_format_id")
);

CREATE TABLE "Attribute" (
  attribute_id SERIAL NOT NULL,
  name VARCHAR(50) DEFAULT '' NOT NULL,
  PRIMARY KEY ("attribute_id")
);

CREATE TABLE "Category" (
  category_id SERIAL NOT NULL,
  name VARCHAR(50) DEFAULT '' NOT NULL,
  display_order SMALLINT DEFAULT 0 NOT NULL,
  PRIMARY KEY ("category_id")
);

CREATE TABLE "Cuisine" (
  cuisine_id SERIAL NOT NULL,
  name VARCHAR(40) DEFAULT '' NOT NULL,
  parent_cuisine_id INTEGER DEFAULT NULL,
  PRIMARY KEY ("cuisine_id"),
  CONSTRAINT "Cuisine___name" UNIQUE ("name")
);
CREATE INDEX "Cuisine___parent_cuisine_id" on "Cuisine" ("parent_cuisine_id");

CREATE TABLE "Locale" (
  locale_id SERIAL NOT NULL,
  locale_code VARCHAR(15) DEFAULT '' NOT NULL,
  address_format_id SMALLINT NOT NULL,
  requires_localized_addresses BOOL DEFAULT FALSE NOT NULL,
  PRIMARY KEY ("locale_id")
);

CREATE TABLE "LocaleEncoding" (
  locale_id BIGINT NOT NULL,
  encoding_name VARCHAR(15) DEFAULT '' NOT NULL,
  PRIMARY KEY ("locale_id", "encoding_name")
);
CREATE INDEX "LocaleEncoding___locale_id" on "LocaleEncoding" ("locale_id");
CREATE INDEX "LocaleEncoding___encoding_name" on "LocaleEncoding" ("encoding_name");

CREATE TABLE "Location" (
  location_id BIGSERIAL NOT NULL,
  name VARCHAR(200) DEFAULT '' NOT NULL,
  localized_name VARCHAR(200) DEFAULT NULL,
  time_zone_name VARCHAR(100) DEFAULT NULL,
  can_have_vendors BOOL DEFAULT FALSE NOT NULL,
  is_country BOOL DEFAULT FALSE NOT NULL,
  parent_location_id INTEGER DEFAULT NULL,
  locale_id BIGINT DEFAULT NULL,
  creation_datetime timestamp DEFAULT '2007-01-01 00:00:00' NOT NULL,
  user_id BIGINT DEFAULT 1 NOT NULL,
  has_addresses BOOL DEFAULT TRUE NOT NULL,
  has_hours BOOL DEFAULT TRUE NOT NULL,
  PRIMARY KEY ("location_id")
);
CREATE INDEX "Location___name___parent_location_id" on "Location" ("name", "parent_location_id");
CREATE INDEX "Location___locale_id" on "Location" ("locale_id");
CREATE INDEX "Location___parent_location_id" on "Location" ("parent_location_id");

CREATE TABLE "LocationComment" (
  location_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  comment TEXT NOT NULL,
  last_modified_datetime timestamp DEFAULT '0000-00-00 00:00:00' NOT NULL,
  PRIMARY KEY ("location_id", "user_id")
);
CREATE INDEX "LocationComment___user_id" on "LocationComment" ("user_id");
CREATE INDEX "LocationComment___location_id" on "LocationComment" ("location_id");

CREATE TABLE "LocationOwner" (
  location_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  PRIMARY KEY ("location_id", "user_id")
);
CREATE INDEX "LocationOwner___user_id" on "LocationOwner" ("user_id");
CREATE INDEX "LocationOwner___location_id" on "LocationOwner" ("location_id");

CREATE TABLE "NewsItem" (
  item_id SERIAL NOT NULL,
  title VARCHAR(250) NOT NULL,
  creation_datetime timestamp NOT NULL,
  body TEXT NOT NULL,
  PRIMARY KEY ("item_id")
);

CREATE TABLE "PaymentOption" (
  payment_option_id SERIAL NOT NULL,
  name VARCHAR(50) DEFAULT '' NOT NULL,
  PRIMARY KEY ("payment_option_id")
);

CREATE TABLE "PriceRange" (
  price_range_id SERIAL NOT NULL,
  description VARCHAR(30) NOT NULL,
  display_order SMALLINT NOT NULL,
  PRIMARY KEY ("price_range_id")
);

CREATE TABLE "Session" (
  id VARCHAR(72) NOT NULL,
  session_data BYTEA NOT NULL,
  expires BIGINT NOT NULL,
  PRIMARY KEY ("id")
);

CREATE TABLE "User" (
  user_id BIGSERIAL NOT NULL,
  email_address VARCHAR(150) DEFAULT '' NOT NULL,
  password VARCHAR(40) DEFAULT '' NOT NULL,
  real_name VARCHAR(100) DEFAULT '' NOT NULL,
  home_page VARCHAR(150) DEFAULT NULL,
  creation_datetime timestamp DEFAULT '0000-00-00 00:00:00' NOT NULL,
  forgot_password_digest VARCHAR(40) DEFAULT NULL,
  forgot_password_digest_datetime timestamp DEFAULT NULL,
  is_admin BOOL DEFAULT FALSE NOT NULL,
  allows_email BOOL DEFAULT FALSE NOT NULL,
  entries_per_page BIGINT DEFAULT 20 NOT NULL,
  openid_uri VARCHAR(255) DEFAULT NULL,
  bio TEXT,
  how_veg SMALLINT NOT NULL,
  image_extension VARCHAR(3) DEFAULT NULL,
  PRIMARY KEY ("user_id"),
  CONSTRAINT "User___email_address" UNIQUE ("email_address"),
  CONSTRAINT "User___real_name" UNIQUE ("real_name"),
  CONSTRAINT "User___openid_uri" UNIQUE ("openid_uri")
);

CREATE TABLE "UserActivityLog" (
  user_activity_log_id BIGSERIAL NOT NULL,
  user_id BIGINT NOT NULL,
  user_activity_log_type_id SMALLINT NOT NULL,
  activity_datetime timestamp DEFAULT '0000-00-00 00:00:00' NOT NULL,
  comment TEXT,
  vendor_id BIGINT DEFAULT NULL,
  location_id BIGINT DEFAULT NULL,
  PRIMARY KEY ("user_activity_log_id")
);
CREATE INDEX "UserActivityLog___user_id" on "UserActivityLog" ("user_id");

CREATE TABLE "UserActivityLogType" (
  user_activity_log_type_id SERIAL NOT NULL,
  type VARCHAR(30) DEFAULT '' NOT NULL,
  PRIMARY KEY ("user_activity_log_type_id")
);

CREATE TABLE "UserLocationSubscription" (
  user_id BIGINT NOT NULL,
  location_id BIGINT NOT NULL,
  PRIMARY KEY ("user_id", "location_id")
);
CREATE INDEX "UserLocationSubscription___user_id" on "UserLocationSubscription" ("user_id");
CREATE INDEX "UserLocationSubscription___location_id" on "UserLocationSubscription" ("location_id");

CREATE TABLE "Vendor" (
  vendor_id BIGSERIAL NOT NULL,
  name VARCHAR(100) DEFAULT '' NOT NULL,
  localized_name VARCHAR(100) DEFAULT NULL,
  short_description VARCHAR(250) DEFAULT '' NOT NULL,
  localized_short_description VARCHAR(250) DEFAULT NULL,
  long_description TEXT,
  address1 VARCHAR(255) DEFAULT NULL,
  localized_address1 VARCHAR(255) DEFAULT NULL,
  address2 VARCHAR(255) DEFAULT NULL,
  localized_address2 VARCHAR(255) DEFAULT NULL,
  neighborhood VARCHAR(250) DEFAULT NULL,
  localized_neighborhood VARCHAR(250) DEFAULT NULL,
  directions TEXT,
  city VARCHAR(150) DEFAULT NULL,
  localized_city VARCHAR(150) DEFAULT NULL,
  region VARCHAR(100) DEFAULT NULL,
  localized_region VARCHAR(100) DEFAULT NULL,
  postal_code VARCHAR(30) DEFAULT NULL,
  phone VARCHAR(25) DEFAULT NULL,
  home_page VARCHAR(150) DEFAULT NULL,
  veg_level SMALLINT DEFAULT 1 NOT NULL,
  allows_smoking SMALLINT DEFAULT NULL,
  is_wheelchair_accessible SMALLINT DEFAULT NULL,
  accepts_reservations SMALLINT DEFAULT NULL,
  creation_datetime timestamp DEFAULT '0000-00-00 00:00:00' NOT NULL,
  last_modified_datetime timestamp DEFAULT '0000-00-00 00:00:00' NOT NULL,
  last_featured_date date DEFAULT NULL,
  user_id INTEGER NOT NULL,
  location_id INTEGER NOT NULL,
  price_range_id SMALLINT NOT NULL,
  localized_long_description TEXT,
  latitude numeric(8,2) DEFAULT NULL,
  longitude numeric(8,2) DEFAULT NULL,
  is_cash_only BOOL DEFAULT FALSE NOT NULL,
  close_date date DEFAULT NULL,
  canonical_address TEXT,
  external_unique_id VARCHAR(255) DEFAULT NULL,
  vendor_source_id BIGINT DEFAULT NULL,
  sortable_name VARCHAR(255) NOT NULL,
  PRIMARY KEY ("vendor_id"),
  CONSTRAINT "Vendor___external_unique_id___vendor_source_id" UNIQUE ("external_unique_id", "vendor_source_id")
);
CREATE INDEX "Vendor___location_id" on "Vendor" ("location_id");
CREATE INDEX "Vendor___postal_code___5" on "Vendor" (postal_code(5));
CREATE INDEX "Vendor___user_id" on "Vendor" ("user_id");
CREATE INDEX "Vendor___price_range_id" on "Vendor" ("price_range_id");
CREATE INDEX "Vendor___canonical_address___200" on "Vendor" (canonical_address(200));

CREATE TABLE "VendorAttribute" (
  vendor_id BIGINT NOT NULL,
  attribute_id BIGINT NOT NULL,
  PRIMARY KEY ("vendor_id", "attribute_id")
);

CREATE TABLE "VendorCategory" (
  vendor_id BIGINT NOT NULL,
  category_id BIGINT NOT NULL,
  PRIMARY KEY ("vendor_id", "category_id")
);
CREATE INDEX "VendorCategory___category_id" on "VendorCategory" ("category_id");
CREATE INDEX "VendorCategory___vendor_id" on "VendorCategory" ("vendor_id");

CREATE TABLE "VendorComment" (
  vendor_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  comment TEXT,
  last_modified_datetime timestamp DEFAULT '0000-00-00 00:00:00' NOT NULL,
  PRIMARY KEY ("vendor_id", "user_id")
);
CREATE INDEX "VendorComment___user_id" on "VendorComment" ("user_id");
CREATE INDEX "VendorComment___vendor_id" on "VendorComment" ("vendor_id");

CREATE TABLE "VendorCuisine" (
  vendor_id BIGINT NOT NULL,
  cuisine_id BIGINT NOT NULL,
  PRIMARY KEY ("vendor_id", "cuisine_id")
);
CREATE INDEX "VendorCuisine___cuisine_id" on "VendorCuisine" ("cuisine_id");
CREATE INDEX "VendorCuisine___vendor_id" on "VendorCuisine" ("vendor_id");

CREATE TABLE "VendorHours" (
  vendor_id INTEGER NOT NULL,
  day SMALLINT NOT NULL,
  open_minute BIGINT NOT NULL,
  close_minute INTEGER NOT NULL,
  PRIMARY KEY ("vendor_id", "day", "open_minute", "close_minute")
);
CREATE INDEX "VendorHours___vendor_id" on "VendorHours" ("vendor_id");

CREATE TABLE "VendorImage" (
  vendor_image_id SERIAL NOT NULL,
  vendor_id BIGINT NOT NULL,
  display_order SMALLINT NOT NULL,
  extension VARCHAR(3) NOT NULL,
  caption TEXT,
  user_id BIGINT NOT NULL,
  PRIMARY KEY ("vendor_image_id")
);
CREATE INDEX "VendorImage___vendor_id___display_order" on "VendorImage" ("vendor_id", "display_order");

CREATE TABLE "VendorPaymentOption" (
  payment_option_id BIGINT NOT NULL,
  vendor_id BIGINT NOT NULL,
  PRIMARY KEY ("payment_option_id", "vendor_id")
);
CREATE INDEX "VendorPaymentOption___vendor_id" on "VendorPaymentOption" ("vendor_id");
CREATE INDEX "VendorPaymentOption___payment_option_id" on "VendorPaymentOption" ("payment_option_id");

CREATE TABLE "VendorRating" (
  vendor_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  rating SMALLINT NOT NULL,
  rating_datetime timestamp NOT NULL,
  PRIMARY KEY ("vendor_id", "user_id")
);
CREATE INDEX "VendorRating___user_id" on "VendorRating" ("user_id");
CREATE INDEX "VendorRating___vendor_id" on "VendorRating" ("vendor_id");

CREATE TABLE "VendorSource" (
  vendor_source_id SERIAL NOT NULL,
  name VARCHAR(255) NOT NULL,
  display_uri VARCHAR(255) NOT NULL,
  feed_uri VARCHAR(255) NOT NULL,
  filter_class VARCHAR(50) NOT NULL,
  last_processed_datetime timestamp DEFAULT NULL,
  PRIMARY KEY ("vendor_source_id"),
  CONSTRAINT "VendorSource___feed_uri" UNIQUE ("feed_uri")
);

CREATE TABLE "VendorSourceExcludedId" (
  vendor_source_id BIGINT NOT NULL,
  external_unique_id VARCHAR(255) NOT NULL,
  PRIMARY KEY ("vendor_source_id", "external_unique_id")
);

CREATE TABLE "VendorSuggestion" (
  vendor_suggestion_id SERIAL NOT NULL,
  type VARCHAR(10) DEFAULT '' NOT NULL,
  suggestion BYTEA NOT NULL,
  comment TEXT,
  user_wants_notification SMALLINT NOT NULL,
  creation_datetime timestamp DEFAULT '0000-00-00 00:00:00' NOT NULL,
  vendor_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  PRIMARY KEY ("vendor_suggestion_id")
);

CREATE INDEX "VendorSuggestion___user_id" on "VendorSuggestion" ("user_id");
CREATE INDEX "VendorSuggestion___vendor_id" on "VendorSuggestion" ("vendor_id");
