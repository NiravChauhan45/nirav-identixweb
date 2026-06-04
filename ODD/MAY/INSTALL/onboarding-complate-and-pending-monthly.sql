WITH main_data AS (
    SELECT 
        ac.store_name,
        ac.action,
        ac.page,
        ac.created_at,
        cs.created_on
    FROM admin_user_activity ac
    JOIN client_store cs ON ac.store_name = cs.store_name
    WHERE 
        CONVERT_TZ(ac.created_at, '+00:00', '+05:30') 
            BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        AND cs.shop_plan NOT IN (
            'Development', 'Staff', 'Developer Preview', 'Trial',
            'Shopify Plus Partner Sandbox', 'affiliate', 'partner_test',
            'plus_partner_sandbox', 'Pause and Build', 'Staff Business',
            'fraudulent', 'Canceled', 'Frozen', 'Fraudulent', 'cancelled', 'frozen'
        )
        AND cs.shop_plan         NOT LIKE '%Development%'
        AND cs.plan_display_name NOT LIKE '%Development%'
),

fresh_installs AS (
    SELECT 
        md.store_name,
        MAX(md.created_at) AS created_at
    FROM main_data md
    WHERE 
        md.action IN (
            'fresh_install', 'Fresh installs', 'Fresh Installs',
            'reinstall', 'Re-installs', 'reopen', 'store re-opened'
        )
        AND CONVERT_TZ(md.created_on, '+00:00', '+05:30') 
            BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        AND NOT EXISTS (
            SELECT 1 FROM admin_user_activity u
            WHERE u.store_name = md.store_name
              AND (
                  u.action IN ('uninstall', 'Paid uninstalled', 'Store closed')
                  OR u.page = 'uninstall'
              )
              AND u.created_at > md.created_at
              AND CONVERT_TZ(u.created_at, '+00:00', '+05:30') 
                  BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        )
    GROUP BY md.store_name
),
onboarding_completed AS (
    SELECT
        aua.store_name
    FROM fresh_installs fi
    JOIN admin_user_activity aua
        ON fi.store_name = aua.store_name
    WHERE aua.action IN (
        'Onboarding—completed',
        'Onboarding completed',
        'onboarding completed'
    )
    AND aua.created_at BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
    GROUP BY aua.store_name
),

onboarding_pending AS (
    SELECT
        fi.store_name
    FROM fresh_installs fi
    LEFT JOIN onboarding_completed oc
        ON fi.store_name = oc.store_name
    WHERE oc.store_name IS NULL
)

-- SELECT * FROM onboarding_completed


SELECT
   (SELECT COUNT(*) FROM fresh_installs) AS fresh_installs,
   (SELECT COUNT(*) FROM onboarding_pending) AS onboarding_pending,
   (SELECT COUNT(*) FROM onboarding_completed) AS onboarding_completed;