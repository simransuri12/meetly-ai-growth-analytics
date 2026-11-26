
/*
============================================================
PROJECT: MEETLY AI — GROWTH ANALYTICS
FILE: 01_database_setup_and_data_quality.sql

/* =========================================================
   SECTION 1: DATABASE SETUP
   ========================================================= */

-- Create the database if it does not already exist.
CREATE DATABASE IF NOT EXISTS meetly_ai;

-- Select the database for subsequent operations.
USE meetly_ai;

-- Display available databases.
SHOW DATABASES;


/* =========================================================
   SECTION 2: CREATE DATABASE TABLES
   ========================================================= */

-- TABLE 1: CAMPAIGNS
-- Stores marketing campaign information, performance metrics,
-- and advertising spend.

CREATE TABLE IF NOT EXISTS campaigns (
    campaign_id VARCHAR(20) PRIMARY KEY,
    campaign_name VARCHAR(100),
    channel VARCHAR(50),
    start_date DATE,
    end_date DATE,
    impressions INT,
    clicks INT,
    spend_usd DECIMAL(10,2)
);


-- TABLE 2: USERS
-- Stores user registration, demographic information,
-- and acquisition source.
-- campaign_id connects users to their acquisition campaigns.

CREATE TABLE IF NOT EXISTS users (
    user_id VARCHAR(20) PRIMARY KEY,
    signup_date DATE,
    profession VARCHAR(100),
    country VARCHAR(100),
    acquisition_source VARCHAR(50),
    campaign_id VARCHAR(20),

    FOREIGN KEY (campaign_id)
        REFERENCES campaigns(campaign_id)
);


-- TABLE 3: SESSIONS
-- Stores user sessions, including session time,
-- device type, and landing page.

CREATE TABLE IF NOT EXISTS sessions (
    session_id VARCHAR(20) PRIMARY KEY,
    user_id VARCHAR(20),
    session_start DATETIME,
    device VARCHAR(50),
    landing_page VARCHAR(255),

    FOREIGN KEY (user_id)
        REFERENCES users(user_id)
);


-- TABLE 4: USER EVENTS
-- Stores individual user activities and feature interactions.
-- event_success indicates whether an event was successful.

CREATE TABLE IF NOT EXISTS user_events (
    event_id VARCHAR(20) PRIMARY KEY,
    user_id VARCHAR(20),
    session_id VARCHAR(20),
    event_name VARCHAR(100),
    event_timestamp DATETIME,
    feature_name VARCHAR(100),
    event_success BOOLEAN,

    FOREIGN KEY (user_id)
        REFERENCES users(user_id),

    FOREIGN KEY (session_id)
        REFERENCES sessions(session_id)
);


-- TABLE 5: SUBSCRIPTIONS
-- Stores subscription plans, pricing, dates,
-- and subscription status.

CREATE TABLE IF NOT EXISTS subscriptions (
    subscription_id VARCHAR(20) PRIMARY KEY,
    user_id VARCHAR(20),
    plan_name VARCHAR(50),
    start_date DATE,
    end_date DATE,
    monthly_price_usd DECIMAL(10,2),
    status VARCHAR(30),

    FOREIGN KEY (user_id)
        REFERENCES users(user_id)
);


-- TABLE 6: EXPERIMENTS
-- Stores user assignments to A/B testing experiments
-- and their respective variants.

CREATE TABLE IF NOT EXISTS experiments (
    assignment_id VARCHAR(20) PRIMARY KEY,
    experiment_name VARCHAR(100),
    user_id VARCHAR(20),
    variant VARCHAR(50),
    assignment_timestamp DATETIME,

    FOREIGN KEY (user_id)
        REFERENCES users(user_id)
);


/* =========================================================
   SECTION 3: DATABASE STRUCTURE VERIFICATION
   ========================================================= */

-- Confirm the active database.
SELECT DATABASE();

-- Display all tables in the Meetly AI database.
SHOW TABLES;


/* =========================================================
   SECTION 4: CSV IMPORT CONFIGURATION
   ========================================================= */

-- Enable LOCAL INFILE for the current MySQL server session.
-- This setting was used while troubleshooting CSV imports.
-- The Python connector was ultimately used for importing data.

SET GLOBAL local_infile = 1;

-- Verify whether LOCAL INFILE is enabled.
SHOW VARIABLES LIKE 'local_infile';

-- Check the secure file import directory configuration.
SHOW VARIABLES LIKE 'secure_file_priv';


/* =========================================================
   SECTION 5: VERIFY IMPORTED DATA
   ========================================================= */

-- Check the number of records imported into each table.

SELECT 'campaigns' AS table_name, COUNT(*) AS total_rows
FROM campaigns

UNION ALL

SELECT 'users', COUNT(*)
FROM users

UNION ALL

SELECT 'sessions', COUNT(*)
FROM sessions

UNION ALL

SELECT 'user_events', COUNT(*)
FROM user_events

UNION ALL

SELECT 'subscriptions', COUNT(*)
FROM subscriptions

UNION ALL

SELECT 'experiments', COUNT(*)
FROM experiments;


/* =========================================================
   SECTION 6: DATA QUALITY CHECKS
   ========================================================= */

-- DATA QUALITY CHECK 1:
-- Check for missing values in the users table.

SELECT
    COUNT(*) AS total_users,
    SUM(user_id IS NULL) AS missing_user_id,
    SUM(signup_date IS NULL) AS missing_signup_date,
    SUM(profession IS NULL) AS missing_profession,
    SUM(country IS NULL) AS missing_country,
    SUM(acquisition_source IS NULL) AS missing_acquisition_source,
    SUM(campaign_id IS NULL) AS missing_campaign_id
FROM users;


-- DATA QUALITY CHECK 2:
-- Examine user distribution by profession.
-- COALESCE replaces NULL with 'Unknown' in the query output.
-- The original database values remain unchanged.

SELECT
    COALESCE(profession, 'Unknown') AS profession,
    COUNT(*) AS total_users
FROM users
GROUP BY COALESCE(profession, 'Unknown')
ORDER BY total_users DESC;


-- DATA QUALITY CHECK 3:
-- Identify duplicate user records.
-- Compare total rows with distinct user IDs.
-- Expected result: 0 duplicate users.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT user_id) AS unique_users,
    COUNT(*) - COUNT(DISTINCT user_id) AS duplicate_users
FROM users;


-- DATA QUALITY CHECK 4:
-- Examine user distribution by country.
-- Missing country values are displayed as 'Unknown'.

SELECT
    COALESCE(country, 'Unknown') AS country,
    COUNT(*) AS total_users
FROM users
GROUP BY COALESCE(country, 'Unknown')
ORDER BY total_users DESC;


/* =========================================================
   SECTION 7: FOREIGN KEY / RELATIONSHIP VALIDATION
   ========================================================= */

-- Check whether records in related tables reference
-- valid records in their parent tables.
-- Expected result: 0 invalid records for each relationship.


-- CHECK 1: Users → Campaigns
-- Every non-NULL campaign_id should exist in campaigns.

SELECT
    'Users → Campaigns' AS relationship,
    COUNT(*) AS invalid_records
FROM users u
LEFT JOIN campaigns c
    ON u.campaign_id = c.campaign_id
WHERE u.campaign_id IS NOT NULL
  AND c.campaign_id IS NULL

UNION ALL


-- CHECK 2: Sessions → Users
-- Every session should belong to an existing user.

SELECT
    'Sessions → Users',
    COUNT(*)
FROM sessions s
LEFT JOIN users u
    ON s.user_id = u.user_id
WHERE u.user_id IS NULL

UNION ALL


-- CHECK 3: Events → Users
-- Every event should belong to an existing user.

SELECT
    'Events → Users',
    COUNT(*)
FROM user_events e
LEFT JOIN users u
    ON e.user_id = u.user_id
WHERE u.user_id IS NULL

UNION ALL


-- CHECK 4: Subscriptions → Users
-- Every subscription should belong to an existing user.

SELECT
    'Subscriptions → Users',
    COUNT(*)
FROM subscriptions s
LEFT JOIN users u
    ON s.user_id = u.user_id
WHERE u.user_id IS NULL

UNION ALL


-- CHECK 5: Experiments → Users
-- Every experiment assignment should belong to an existing user.

SELECT
    'Experiments → Users',
    COUNT(*)
FROM experiments e
LEFT JOIN users u
    ON e.user_id = u.user_id
WHERE u.user_id IS NULL;


