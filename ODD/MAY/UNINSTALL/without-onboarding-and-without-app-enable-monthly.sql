WITH latest_uninstall AS(
    SELECT 
        a.store_name,
        MAX(a.created_at) AS uninstall_at
    FROM admin_user_activity a
    JOIN client_store cs
        ON cs.store_name = a.store_name
    WHERE
        DATE(CONVERT_TZ(a.created_at, '+00:00', '+05:30')) BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        AND (
            (a.action IN ('uninstall', 'Paid uninstalled'))
            OR (a.page = 'uninstall')
            OR a.action = 'Store closed'
        )
        /* Install exists in date range */
        AND EXISTS (
            SELECT 1
            FROM admin_user_activity install_ev
            WHERE install_ev.store_name = a.store_name
              AND install_ev.action IN ('fresh_install','Fresh Installs')
              AND DATE(CONVERT_TZ(install_ev.created_at, '+00:00', '+05:30')) BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        )
        /* Last uninstall in range */
        AND a.created_at = (
            SELECT MAX(u.created_at)
            FROM admin_user_activity u
            WHERE u.store_name = a.store_name
              AND (
                    (u.action IN ('uninstall', 'Paid uninstalled'))
                    OR (u.page = 'uninstall')
                  )
              AND DATE(CONVERT_TZ(u.created_at, '+00:00', '+05:30')) BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        )
        /* Install and uninstall in same month */
        AND EXISTS (
            SELECT 1
            FROM admin_user_activity install_month_check
            WHERE install_month_check.store_name = a.store_name
              AND install_month_check.action IN ('fresh_install','Fresh Installs')
              AND DATE_FORMAT(CONVERT_TZ(install_month_check.created_at, '+00:00', '+05:30'),
                    '%Y-%m'
                  ) = DATE_FORMAT(
                    CONVERT_TZ(a.created_at, '+00:00', '+05:30'),
                    '%Y-%m'
                  )
              AND DATE(CONVERT_TZ(install_month_check.created_at, '+00:00', '+05:30')) BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        )

        /* No reinstall after uninstall */
        AND NOT EXISTS (
            SELECT 1
            FROM admin_user_activity later
            WHERE later.store_name = a.store_name
              AND later.created_at > a.created_at
              AND DATE(CONVERT_TZ(later.created_at, '+00:00', '+05:30')) BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
              AND later.action IN (
                    'install', 'fresh_install', 'Fresh Installs', 'reinstall', 'Re-installs')
        )

        /* Plan exclusions */
        AND cs.shop_plan NOT IN (
            'Development', 'Staff', 'Developer Preview', 'Trial',
            'Shopify Plus Partner Sandbox', 'affiliate', 'partner_test',
            'plus_partner_sandbox', 'Staff Business'
        )

        AND (
            cs.plan_display_name IS NULL
            OR cs.plan_display_name NOT IN (
                'Development','Staff','Developer Preview','Trial',
                'Shopify Plus Partner Sandbox','affiliate','staff',
                'partner_test','trial','plus_partner_sandbox','Staff Business'
            )
        )

        AND (
            cs.plan_display_name IS NULL
            OR cs.plan_display_name NOT LIKE '%Development%'
        )

    AND cs.shop_plan NOT LIKE '%Development%'
    GROUP BY a.store_name
    ORDER BY a.store_name
),
onboarding_steps AS(
	SELECT
	    store_name,
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
	GROUP BY store_name	
),
main_data AS(
	SELECT
	    DATE_FORMAT(lu.uninstall_at, '%Y-%m') AS MONTH,
	    cs.store_name,
	    COUNT(
		DISTINCT CASE
		    WHEN IFNULL(os.step3, 0) = 0
		    THEN lu.store_name
		END
	    ) AS `Without finishing Onboarding`,
	    COUNT(
		DISTINCT CASE
		    WHEN NOT EXISTS (
			SELECT 1
			FROM admin_user_activity a
			WHERE a.store_name = lu.store_name
			  AND a.action IN ('App Enabled', 'App enabled-odd')
		    )
		    THEN lu.store_name
		END
	    ) AS `Without App Enabled`
	FROM latest_uninstall lu
	JOIN client_store cs
	    ON cs.store_name = lu.store_name
	JOIN onboarding_steps os
	    ON os.store_name = lu.store_name
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

	    AND CONVERT_TZ(cs.created_on, '+00:00', '+05:30') >= '2026-05-01 00:00:00'
	    AND CONVERT_TZ(cs.created_on, '+00:00', '+05:30') <= '2026-05-31 23:59:59'
	GROUP BY MONTH, cs.store_name
	ORDER BY MONTH, cs.store_name
)


SELECT
    MONTH,
    COUNT(CASE WHEN `Without finishing Onboarding` = 1 THEN 1 END) AS `Without finishing Onboarding`,
    COUNT(CASE WHEN `Without App Enabled` = 1 THEN 1 END) AS `Without App Enabled`
FROM main_data
GROUP BY MONTH;