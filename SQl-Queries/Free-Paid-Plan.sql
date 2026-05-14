WITH last_unistall AS(
    SELECT
       store_client_id,
       MAX(created_at) AS uninstall_at
    FROM admin_user_activity
    WHERE 
        ACTION IN ('uninstall', 'UNINSTALLED')
        AND created_at >= '2026-03-01 00:00:00'
        AND created_at <= '2026-03-31 23:59:59'
    GROUP BY store_client_id
),

aggregation_data AS(
    SELECT
        store_client_id,
        SUM(ACTION = 'During trial') AS during_trail_count,
        SUM(ACTION = 'Free User') AS free_user_count,
        SUM(ACTION = 'uninstall') AS uninstall_count,
        SUM(ACTION = 'Paid uninstalled') AS upgrade_count
    FROM admin_user_activity
    GROUP BY store_client_id
)

SELECT
    DATE_FORMAT(lu.uninstall_at, '%Y-%m') AS MONTH,
    COUNT(
       DISTINCT
          CASE 
	     WHEN
		ad.during_trail_count >=1
		AND ad.uninstall_count >=1
        AND ad.upgrade_count = 0
		AND cs.created_on >= '2026-03-01 00:00:00'
		AND cs.created_on <= '2026-03-31 23:59:59'
	     THEN lu.store_client_id
	   END
    ) AS `During Trial Monthly`,
    COUNT(
      DISTINCT
        CASE
            WHEN
                ad.during_trail_count >= 1 
                AND ad.uninstall_count >= 1
                AND ad.upgrade_count = 0
                AND cs.created_on < '2026-03-01 00:00:00'
            THEN lu.store_client_id
        END
    ) AS `During trail Overall`,
    COUNT(
      DISTINCT
        CASE
            WHEN
                ad.uninstall_count >= 1
                AND ad.free_user_count >= 1
                AND cs.created_on >= '2026-03-01 00:00:00'
                AND cs.created_on <= '2026-03-31 23:59:59'
            THEN lu.store_client_id
        END
    ) AS `Free Plan Montly`,
    COUNT(
      DISTINCT
        CASE
            WHEN
                ad.uninstall_count >= 1
                AND ad.free_user_count >= 1
                AND cs.created_on < '2026-03-01 00:00:00'
            THEN lu.store_client_id
        END
    ) AS `Free Plan Overall`,
    COUNT(
      DISTINCT
        CASE
            WHEN
                ad.upgrade_count >= 1
                AND cs.created_on >= '2026-03-01 00:00:00'
                AND cs.created_on <= '2026-03-31 23:59:59'
            THEN lu.store_client_id
        END
    ) AS `Paid Plan Montly`,
    COUNT(
      DISTINCT
        CASE
            WHEN
		ad.during_trail_count = 0 
		AND ad.upgrade_count >= 1
                AND cs.created_on < '2026-03-01 00:00:00'
            THEN lu.store_client_id
        END
    ) AS `Paid Plan Overall`
FROM last_unistall lu
JOIN client_store cs
   ON cs.store_client_id = lu.store_client_id
JOIN aggregation_data ad
   ON ad.store_client_id = lu.store_client_id
WHERE
    cs.shop_plan NOT IN (
        'Development','Staff','Developer Preview','Trial',
        'Shopify Plus Partner Sandbox','affiliate','staff',
        'Pause and Build','partner_test','trial','plus_partner_sandbox', 'Basic App Development', 'Staff Business'
    )
    AND cs.plan_display_name NOT IN (
        'Development','Staff','Developer Preview','Trial',
        'Shopify Plus Partner Sandbox','affiliate','staff',
        'Pause and Build','partner_test','trial','plus_partner_sandbox', 'Basic App Development', 'Staff Business'
    )
GROUP BY MONTH
ORDER BY MONTH;
