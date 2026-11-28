USE meetly_ai;

-- =====================================================
-- ACQUISITION ANALYSIS 01: CAMPAIGN PERFORMANCE
-- Business question:
-- Which campaigns generate the most signups,
-- and what is the cost per attributed signup?
-- =====================================================

SELECT
    c.campaign_id,
    c.campaign_name,
    c.channel,

    -- Marketing performance
    c.impressions,
    c.clicks,

    -- Click-through rate (%)
    ROUND(
        100.0 * c.clicks / NULLIF(c.impressions, 0),
        2
    ) AS ctr_pct,

    -- Advertising spend
    c.spend_usd,

    -- Cost per click ($)
    ROUND(
        c.spend_usd / NULLIF(c.clicks, 0),
        2
    ) AS cpc_usd,

    -- Number of users attributed to each campaign
    COUNT(u.user_id) AS attributed_signups,

    -- Spend per attributed signup ($)
    ROUND(
        c.spend_usd / NULLIF(COUNT(u.user_id), 0),
        2
    ) AS cost_per_signup_usd

FROM campaigns c

LEFT JOIN users u
    ON c.campaign_id = u.campaign_id

GROUP BY
    c.campaign_id,
    c.campaign_name,
    c.channel,
    c.impressions,
    c.clicks,
    c.spend_usd

ORDER BY attributed_signups DESC;

-- Meetly AI: 7-Day Activation Analysis
-- A user is activated if they complete at least one
-- successful meaningful action within 7 days of signup.

SELECT
    COUNT(DISTINCT u.user_id) AS total_users,

    COUNT(DISTINCT CASE
        WHEN e.user_id IS NOT NULL THEN u.user_id
    END) AS activated_users,

    ROUND(
        COUNT(DISTINCT CASE
            WHEN e.user_id IS NOT NULL THEN u.user_id
        END) * 100.0
        / COUNT(DISTINCT u.user_id),
        2
    ) AS activation_rate_pct

FROM users u

-- 7 day activation 

LEFT JOIN user_events e
    ON u.user_id = e.user_id
    AND e.event_success = 1
    AND e.event_name IN (
        'daily_plan_delivered',
        'ai_email_reply_sent',
        'meeting_summary_delivered',
        'predictive_reminder_delivered'
    )
    AND e.event_timestamp >= u.signup_date
    AND e.event_timestamp < DATE_ADD(u.signup_date, INTERVAL 7 DAY);


-- Meetly AI: Activation Rate by Acquisition Campaign
-- Measures the percentage of users from each campaign
-- who complete a meaningful action within 7 days of signup.

SELECT
    c.campaign_name,
    c.channel,
    COUNT(DISTINCT u.user_id) AS total_signups,

    COUNT(DISTINCT CASE
        WHEN e.user_id IS NOT NULL THEN u.user_id
    END) AS activated_users,

    ROUND(
        COUNT(DISTINCT CASE
            WHEN e.user_id IS NOT NULL THEN u.user_id
        END) * 100.0
        / COUNT(DISTINCT u.user_id),
        2
    ) AS activation_rate_pct

FROM users u

LEFT JOIN campaigns c
    ON u.campaign_id = c.campaign_id

LEFT JOIN user_events e
    ON u.user_id = e.user_id
    AND e.event_success = 1
    AND e.event_name IN (
        'daily_plan_delivered',
        'ai_email_reply_sent',
        'meeting_summary_delivered',
        'predictive_reminder_delivered'
    )
    AND e.event_timestamp >= u.signup_date
    AND e.event_timestamp < DATE_ADD(u.signup_date, INTERVAL 7 DAY)

GROUP BY
    c.campaign_name,
    c.channel

ORDER BY activation_rate_pct DESC;

-- Meetly AI: Feature Adoption Within 7 Days of Signup
-- Counts unique users who successfully used each feature
-- during their first 7 days after signing up.

SELECT
    e.feature_name,
    COUNT(DISTINCT e.user_id) AS users_using_feature,
    COUNT(*) AS successful_events

FROM user_events e

JOIN users u
    ON e.user_id = u.user_id

WHERE e.event_success = 1
    AND e.event_timestamp >= u.signup_date
    AND e.event_timestamp < DATE_ADD(u.signup_date, INTERVAL 7 DAY)
    AND e.feature_name IS NOT NULL

GROUP BY e.feature_name

ORDER BY users_using_feature DESC;

-- Meetly AI: Weekly Active Users (WAU)
-- Counts unique users with at least one successful event each week.

SELECT
    YEARWEEK(event_timestamp, 3) AS year_week,
    COUNT(DISTINCT user_id) AS weekly_active_users

FROM user_events

WHERE event_success = 1

GROUP BY YEARWEEK(event_timestamp, 3)

ORDER BY year_week;


-- Meetly AI: Week-over-Week Returning User Analysis
-- Counts users active in consecutive weeks.

WITH weekly_activity AS (
    SELECT DISTINCT
        user_id,
        DATE_SUB(
            DATE(event_timestamp),
            INTERVAL WEEKDAY(event_timestamp) DAY
        ) AS week_start
    FROM user_events
    WHERE event_success = 1
),

weekly_retention AS (
    SELECT
        current_week.week_start,

        COUNT(DISTINCT current_week.user_id) AS active_users,

        COUNT(DISTINCT CASE
            WHEN previous_week.user_id IS NOT NULL
            THEN current_week.user_id
        END) AS returning_users

    FROM weekly_activity current_week

    LEFT JOIN weekly_activity previous_week
        ON current_week.user_id = previous_week.user_id
        AND previous_week.week_start =
            DATE_SUB(current_week.week_start, INTERVAL 7 DAY)

    GROUP BY current_week.week_start
)

SELECT
    week_start,
    active_users,
    returning_users,

    ROUND(
        returning_users * 100.0 / NULLIF(active_users, 0),
        2
    ) AS week_over_week_return_rate_pct

FROM weekly_retention
ORDER BY week_start;