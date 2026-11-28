-- =====================================================
-- MEETLY AI: MONETIZATION ANALYSIS
-- Step 1: Subscription Overview
-- Purpose: Understand plan selection and subscription status.
-- =====================================================

SELECT
    user_type,
    COUNT(*) AS total_users
FROM (
    SELECT
        u.user_id,
        CASE
            WHEN MAX(CASE
                WHEN s.status = 'Active' AND s.plan_name = 'Pro'
                THEN 1 ELSE 0
            END) = 1 THEN 'Pro'

            WHEN MAX(CASE
                WHEN s.status = 'Active' AND s.plan_name = 'Premium'
                THEN 1 ELSE 0
            END) = 1 THEN 'Premium'

            ELSE 'Free'
        END AS user_type
    FROM users u
    LEFT JOIN subscriptions s
        ON u.user_id = s.user_id
    GROUP BY u.user_id
) AS user_groups
GROUP BY user_type
ORDER BY
    CASE user_type
        WHEN 'Free' THEN 1
        WHEN 'Premium' THEN 2
        WHEN 'Pro' THEN 3
    END;

-- Monthly revenue by premium and pro members
    SELECT
    plan_name,
    COUNT(DISTINCT user_id) AS paying_users,
    SUM(monthly_price_usd) AS monthly_revenue
FROM subscriptions
WHERE status = 'Active'
GROUP BY plan_name;

-- active and cancelled subscriptions
SELECT
    plan_name,
    COUNT(*) AS total_subscriptions,
    SUM(CASE WHEN status = 'Active' THEN 1 ELSE 0 END) AS active_subscriptions,
    SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_subscriptions,
    ROUND(
        SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS cancellation_rate_pct
FROM subscriptions
GROUP BY plan_name
ORDER BY plan_name;

-- Average revenue per user
SELECT
    ROUND(SUM(monthly_price_usd) / COUNT(DISTINCT user_id), 2)
        AS average_revenue_per_paying_user
FROM subscriptions
WHERE status = 'Active';

SELECT
    CONCAT('[', status, ']') AS status_value,
    HEX(status) AS status_hex,
    COUNT(*) AS total_records,
    COUNT(start_date) AS records_with_start_date,
    COUNT(end_date) AS records_with_end_date
FROM subscriptions
GROUP BY status, HEX(status);

-- Calculating LTV
SELECT
    COUNT(*) AS completed_subscriptions,

    ROUND(AVG(DATEDIFF(end_date, start_date)), 1)
        AS average_subscription_days,

    ROUND(AVG(DATEDIFF(end_date, start_date)) / 30.44, 2)
        AS average_subscription_months,

    ROUND(
        18.10 * AVG(DATEDIFF(end_date, start_date)) / 30.44,
        2
    ) AS estimated_ltv

FROM subscriptions
WHERE end_date IS NOT NULL
  AND start_date IS NOT NULL;