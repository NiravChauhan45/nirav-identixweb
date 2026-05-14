WITH filtered_activity AS (
    SELECT
        store_client_id,
        ACTION,
        created_at
    FROM admin_user_activity
    WHERE created_at BETWEEN '2026-04-01 00:00:00' AND '2026-04-30 23:59:59'
),

activity_summary AS (
    SELECT
        store_client_id,
        MAX(CASE WHEN ACTION = 'uninstall' THEN created_at END) AS uninstall_date,
        MAX(CASE WHEN ACTION IN('SPLD-onboarding-step-1', 'PC-onboarding-step-1') THEN 1 ELSE 0 END) AS step1,
        MAX(CASE WHEN ACTION IN('SPLD-onboarding-step-2', 'PC-onboarding-step-2') THEN 1 ELSE 0 END) AS step2,
        MAX(CASE WHEN ACTION IN('SPLD-onboarding-step-3', 'PC-onboarding-step-3') THEN 1 ELSE 0 END) AS step3,
        MAX(CASE WHEN ACTION IN('Onboarding—completed', 'Onboarding completed', 'onboarding completed') THEN 1 ELSE 0 END) AS step4
    FROM filtered_activity
    GROUP BY store_client_id
),

valid_uninstalls AS (
    SELECT
        store_client_id,
        uninstall_date,
        step1,
        step2,
        step3,
        step4
    FROM activity_summary
    WHERE uninstall_date IS NOT NULL
)


SELECT
    DATE_FORMAT(vn.uninstall_date, '%Y-%m') AS MONTH,

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
    ON cs.store_client_id = vn.store_client_id

WHERE
    cs.created_on BETWEEN '2026-04-01 00:00:00' AND '2026-04-30 23:59:59'

    AND cs.shop_plan NOT IN (
        'Development',
        'Staff',
        'Developer Preview',
        'Trial',
        'Shopify Plus Partner Sandbox',
        'affiliate',
        'staff',
        'partner_test',
        'trial',
        'plus_partner_sandbox',
        'Staff Business'
    )

    AND cs.plan_display_name NOT IN (
        'Development',
        'Staff',
        'Developer Preview',
        'Trial',
        'Shopify Plus Partner Sandbox',
        'affiliate',
        'staff',
        'partner_test',
        'trial',
        'plus_partner_sandbox',
        'Staff Business'
    )

GROUP BY MONTH
ORDER BY MONTH;
