WITH months AS (

    /* Generate months dynamically */
    SELECT
        DATE_ADD(
            DATE_FORMAT('2026-05-01', '%Y-%m-01'),
            INTERVAL n MONTH
        ) AS month_start

    FROM (
        SELECT 0 n UNION ALL
        SELECT 1 UNION ALL
        SELECT 2 UNION ALL
        SELECT 3 UNION ALL
        SELECT 4 UNION ALL
        SELECT 5 UNION ALL
        SELECT 6 UNION ALL
        SELECT 7 UNION ALL
        SELECT 8 UNION ALL
        SELECT 9 UNION ALL
        SELECT 10 UNION ALL
        SELECT 11
    ) numbers

    WHERE DATE_ADD(
              DATE_FORMAT('2026-05-01', '%Y-%m-01'),
              INTERVAL n MONTH
          ) <= DATE_FORMAT('2026-05-31', '%Y-%m-01')
),


first_activity AS (

    /* First paid activity per store */
    SELECT
        store_name,
        MIN(created_at) AS first_activity_date

    FROM admin_user_activity

    WHERE ACTION IN (
        'pricing_plan_type-2',
        'pricing_plan_type-3',
        'pricing_plan_type-4'
    )

    GROUP BY store_name
),


valid_stores AS (

    /* Apply all filters */
    SELECT
        DATE_FORMAT(fa.first_activity_date, '%Y-%m-01') AS month_start,
        cs.store_name

    FROM first_activity fa

    JOIN admin_user_activity ac
        ON ac.store_name = fa.store_name
       AND ac.created_at = fa.first_activity_date

    JOIN client_store cs
        ON cs.store_name = ac.store_name

    WHERE fa.first_activity_date BETWEEN '2026-05-01'
                                     AND '2026-05-31'

      AND cs.created_on < '2026-05-01'

      AND cs.shop_plan NOT IN (
            'Development',
            'Staff',
            'Developer Preview',
            'Trial',
            'Shopify Plus Partner Sandbox',
            'affiliate',
            'partner_test',
            'plus_partner_sandbox',
            'Pause and Build',
            'fraudulent',
            'Canceled',
            'Frozen',
            'Fraudulent',
            'cancelled',
            'frozen'
      )

      /* Exclude uninstall stores */
      AND NOT EXISTS (
            SELECT 1
            FROM admin_user_activity ac2
            WHERE ac2.store_name = cs.store_name
              AND ac2.created_at <= '2026-05-31'
              AND ac2.page IN ('uninstall', 'UNINSTALL_APP')
      )
),


monthly_counts AS (

    SELECT
        month_start,
        COUNT(DISTINCT store_name) AS total_stores

    FROM valid_stores

    GROUP BY month_start
)


SELECT
    DATE_FORMAT(m.month_start, '%Y-%m') AS MONTH,
    COALESCE(mc.total_stores, 0) AS total_stores
FROM months m
LEFT JOIN monthly_counts mc
       ON m.month_start = mc.month_start
ORDER BY m.month_start;
