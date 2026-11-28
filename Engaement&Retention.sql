-- =====================================================
-- MEETLY AI: ENGAGEMENT ANALYSIS
-- Step 1: Feature Adoption
-- Purpose: Identify which features users adopt
-- during their first 7 days after signup.
-- =====================================================

SELECT
    e.feature_name,
    COUNT(DISTINCT e.user_id) AS unique_users,
    COUNT(*) AS successful_events

FROM user_events e

JOIN users u
    ON e.user_id = u.user_id

WHERE e.event_success = 1
    AND e.event_timestamp >= u.signup_date
    AND e.event_timestamp < DATE_ADD(
        u.signup_date, INTERVAL 7 DAY
    )
    AND e.feature_name IS NOT NULL

GROUP BY e.feature_name

ORDER BY unique_users DESC;

-- =====================================================
-- MEETLY AI: ENGAGEMENT ANALYSIS
-- Step 2: Setup vs. Core Product Usage
-- Purpose: Compare users completing setup activities
-- with users experiencing the product's core value.
-- =====================================================

SELECT
    CASE
        WHEN e.event_name IN (
            'daily_plan_delivered',
            'ai_email_reply_sent',
            'meeting_summary_delivered',
            'predictive_reminder_delivered'
        ) THEN 'Core Product Usage'

        WHEN e.feature_name IN (
            'onboarding',
            'integration',
            'account'
        ) THEN 'Setup Activity'
    END AS activity_category,

    COUNT(DISTINCT e.user_id) AS unique_users,
    COUNT(*) AS successful_events

FROM user_events e

JOIN users u
    ON e.user_id = u.user_id

WHERE e.event_success = 1
    AND e.event_timestamp >= u.signup_date
    AND e.event_timestamp < DATE_ADD(
        u.signup_date, INTERVAL 7 DAY
    )
    AND (
        e.event_name IN (
            'daily_plan_delivered',
            'ai_email_reply_sent',
            'meeting_summary_delivered',
            'predictive_reminder_delivered'
        )
        OR e.feature_name IN (
            'onboarding',
            'integration',
            'account'
        )
    )

GROUP BY activity_category;

-- =====================================================
-- MEETLY AI: ENGAGEMENT ANALYSIS
-- Step 3: Sessions Per User
-- Purpose: Understand how frequently new users
-- return to the product during their first 7 days.
-- =====================================================

WITH user_sessions AS (
    SELECT
        u.user_id,
        COUNT(s.session_id) AS total_sessions

    FROM users u

    LEFT JOIN sessions s
        ON u.user_id = s.user_id
        AND s.session_start >= u.signup_date
        AND s.session_start < DATE_ADD(
            u.signup_date, INTERVAL 7 DAY
        )

    GROUP BY u.user_id
)

SELECT
    CASE
        WHEN total_sessions = 0 THEN '0 sessions'
        WHEN total_sessions = 1 THEN '1 session'
        WHEN total_sessions BETWEEN 2 AND 3 THEN '2-3 sessions'
        WHEN total_sessions BETWEEN 4 AND 6 THEN '4-6 sessions'
        ELSE '7+ sessions'
    END AS session_group,

    COUNT(*) AS number_of_users

FROM user_sessions

GROUP BY session_group

ORDER BY
    CASE session_group
        WHEN '0 sessions' THEN 1
        WHEN '1 session' THEN 2
        WHEN '2-3 sessions' THEN 3
        WHEN '4-6 sessions' THEN 4
        ELSE 5
    END;

   
-- MEETLY AI: RETENTION ANALYSIS
-- Monthly Cohort Retention
--
-- Purpose:
-- Track the percentage of users who remain active
-- in the months following their signup month.
--
-- Retained user:
-- A user with at least one successful product event
-- during the relevant calendar month.
-- =====================================================

WITH user_cohorts AS (
    SELECT
        user_id,
        DATE_FORMAT(signup_date, '%Y-%m-01') AS cohort_month
    FROM users
),

cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT user_id) AS cohort_size
    FROM user_cohorts
    GROUP BY cohort_month
),

monthly_activity AS (
    SELECT DISTINCT
        user_id,
        DATE_FORMAT(event_timestamp, '%Y-%m-01') AS activity_month
    FROM user_events
    WHERE event_success = 1
),

cohort_retention AS (
    SELECT
        uc.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            uc.cohort_month,
            ma.activity_month
        ) AS months_since_signup,
        COUNT(DISTINCT uc.user_id) AS active_users

    FROM user_cohorts uc

    JOIN monthly_activity ma
        ON uc.user_id = ma.user_id

    WHERE ma.activity_month >= uc.cohort_month

    GROUP BY
        uc.cohort_month,
        months_since_signup
)

SELECT
    cr.cohort_month,
    cr.months_since_signup,
    cs.cohort_size,
    cr.active_users,

    ROUND(
        cr.active_users * 100.0 / cs.cohort_size,
        2
    ) AS retention_rate_pct

FROM cohort_retention cr

JOIN cohort_sizes cs
    ON cr.cohort_month = cs.cohort_month

ORDER BY
    cr.cohort_month,
    cr.months_since_signup;



