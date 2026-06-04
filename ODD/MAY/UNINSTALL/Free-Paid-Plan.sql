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
agg_data AS(
    SELECT
        store_name,
        SUM(ACTION = 'During trial')       AS during_trail_count,
        SUM(ACTION = 'Free User')       AS free_user_count,
        SUM(ACTION = 'uninstall')       AS uninstall_count,
        SUM(ACTION = 'Paid uninstalled')   AS upgrade_count
    FROM admin_user_activity
    GROUP BY store_name
)
SELECT
    DATE_FORMAT(CONVERT_TZ(lu.uninstall_at, '+00:00', '+05:30'), '%Y-%m') AS MONTH,
    
    COUNT(
        DISTINCT
        CASE
            WHEN
                ad.during_trail_count >= 1 
                AND ad.uninstall_count >= 1
                AND ad.upgrade_count = 0
                AND cs.created_on >= '2026-05-01 00:00:00'
                AND cs.created_on <= '2026-05-31 23:59:59'
            THEN lu.store_name
        END
    ) AS `During trail Montly`,
    
    COUNT(
        DISTINCT
        CASE
            WHEN
                ad.during_trail_count >= 1 
                AND ad.uninstall_count >= 1
                AND ad.upgrade_count = 0
                AND cs.created_on < '2026-05-01 00:00:00'
            THEN lu.store_name
        END
    ) AS `During trail Overall`,
    
    COUNT(
        DISTINCT
        CASE
            WHEN
                ad.uninstall_count >= 1
                AND ad.free_user_count >= 1
                AND cs.created_on >= '2026-05-01 00:00:00'
                AND cs.created_on <= '2026-05-31 23:59:59'
            THEN lu.store_name
        END
    ) AS `Free Plan Montly`,
    
    COUNT(
        DISTINCT
        CASE
            WHEN
                ad.uninstall_count >= 1
                AND ad.free_user_count >= 1
                AND cs.created_on < '2026-05-01 00:00:00'
            THEN lu.store_name
        END
    ) AS `Free Plan Overall`,
    
    COUNT(
        DISTINCT
        CASE
            WHEN
                ad.upgrade_count >= 1
                AND cs.created_on >= '2026-05-01 00:00:00'
                AND cs.created_on <= '2026-05-31 23:59:59'
            THEN lu.store_name
        END
    ) AS `Paid Plan Montly`,
    
    COUNT(
        DISTINCT
        CASE
            WHEN
                ad.during_trail_count = 0 AND 
                ad.upgrade_count >= 1
                AND cs.created_on < '2026-05-01 00:00:00'
            THEN lu.store_name
        END
    ) AS `Paid Plan Overall`

FROM latest_uninstall lu
JOIN client_store cs
ON cs.store_name = lu.store_name
JOIN agg_data ad
ON ad.store_name = lu.store_name
GROUP BY MONTH
ORDER BY MONTH;