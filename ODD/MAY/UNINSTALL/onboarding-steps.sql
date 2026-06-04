WITH same_month_uninstall_data AS(
    SELECT 
        a.store_name
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
filtered_activity AS(
    SELECT 
    	smu.store_name,
    	ac.ACTION,
    	ac.created_at
    FROM admin_user_activity ac
    JOIN same_month_uninstall_data smu
    ON ac.store_name = smu.store_name
    WHERE CONVERT_TZ(ac.created_at, '+00:00', '+05:30') BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
),

activity_summary AS (
    SELECT
        store_name,
        MAX(CASE WHEN ACTION IN('uninstall', 'Paid uninstalled') THEN created_at END) AS uninstall_date,
        MAX(CASE WHEN ACTION IN('SPLD-onboarding-step-1', 'PC-onboarding-step-1') THEN 1 ELSE 0 END) AS step1,
        MAX(CASE WHEN ACTION IN('SPLD-onboarding-step-2', 'PC-onboarding-step-2') THEN 1 ELSE 0 END) AS step2,
        MAX(CASE WHEN ACTION IN('SPLD-onboarding-step-3', 'PC-onboarding-step-3') THEN 1 ELSE 0 END) AS step3,
        MAX(CASE WHEN ACTION IN('Onboarding—completed', 'Onboarding completed', 'onboarding completed') THEN 1 ELSE 0 END) AS step4
    FROM filtered_activity
    GROUP BY store_name
),

valid_uninstalls AS (
    SELECT
        store_name,
        uninstall_date,
        step1,
        step2,
        step3,
        step4
    FROM activity_summary
    WHERE uninstall_date IS NOT NULL
)

SELECT
    DATE_FORMAT(CONVERT_TZ(vn.uninstall_date, '+00:00', '+05:30'), '%Y-%m') AS MONTH,
    SUM(
        CASE
            WHEN IFNULL(vn.step1,0) = 0
             AND IFNULL(vn.step2,0) = 0
             AND IFNULL(vn.step3,0) = 0
            THEN 1 ELSE 0
        END
    ) AS `onboarding step 1`,

    SUM(
        CASE
            WHEN vn.step1 = 1
             AND vn.step2 = 0
             AND vn.step3 = 0
             AND vn.step4 = 0
            THEN 1 ELSE 0
        END
    ) AS `onboarding step 2`,

    SUM(
        CASE
            WHEN vn.step2 = 1
             AND vn.step3 = 0
             AND vn.step4 = 0
            THEN 1 ELSE 0
        END
    ) AS `onboarding step 3`,


    SUM(
        CASE
            WHEN vn.step3 = 1
             AND vn.step4 = 0
            THEN 1 ELSE 0
        END
    ) AS `onboarding step 4`,

    SUM(
        CASE
            WHEN vn.step4 = 1
            THEN 1 ELSE 0
        END
    ) AS `onboarding completed`

FROM valid_uninstalls vn

JOIN client_store cs
    ON cs.store_name = vn.store_name

WHERE
    CONVERT_TZ(cs.created_on, '+00:00', '+05:30') BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
GROUP BY MONTH
ORDER BY MONTH;