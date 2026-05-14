WITH latest_uninstall AS (
    SELECT
        store_client_id,
        MAX(created_at) AS uninstall_at
    FROM admin_user_activity
    WHERE ACTION = 'uninstall'
      AND created_at >= '2026-03-01 00:00:00'
      AND created_at <= '2026-03-31 23:59:59'
    GROUP BY store_client_id
),

onboarding_steps AS(
	SELECT
	    store_client_id,
	    MAX(
	      CASE 
	         WHEN ACTION IN(
	            'SPLD-onboarding-step-3', 'PC-onboarding-step-3',
	            'Onboarding—completed','Onboarding completed', 'onboarding completed'
	         ) 
	         THEN 1 ELSE 0 
	      END
	    ) AS step3
	FROM admin_user_activity
	GROUP BY store_client_id	
)

SELECT
    DATE_FORMAT(lu.uninstall_at, '%Y-%m') AS MONTH,

    COUNT(
        DISTINCT CASE
            WHEN IFNULL(os.step3, 0) = 0
            THEN lu.store_client_id
        END
    ) AS `Without finishing Onboarding`,

    COUNT(
        DISTINCT CASE
            WHEN NOT EXISTS (
                SELECT 1
                FROM admin_user_activity a
                WHERE a.store_client_id = lu.store_client_id
                  AND a.action IN ('App Enabled', 'App enabled-odd')
            )
            THEN lu.store_client_id
        END
    ) AS `Without App Enabled`
FROM latest_uninstall lu
JOIN client_store cs
    ON cs.store_client_id = lu.store_client_id
JOIN onboarding_steps os
    ON os.store_client_id = lu.store_client_id
WHERE
    cs.shop_plan NOT IN (
        'Development', 'Staff', 'Developer Preview', 'Trial',
        'Shopify Plus Partner Sandbox', 'affiliate', 'staff',
        'partner_test', 'trial', 'plus_partner_sandbox',
        'Staff Business'
    )
    AND cs.plan_display_name NOT IN (
        'Development', 'Staff', 'Developer Preview', 'Trial',
        'Shopify Plus Partner Sandbox', 'affiliate', 'staff',
        'partner_test', 'trial', 'plus_partner_sandbox',
        'Staff Business'
    )
    AND cs.created_on >= '2026-03-01 00:00:00'
    AND cs.created_on <= '2026-03-31 23:59:59'
GROUP BY MONTH
ORDER BY MONTH;