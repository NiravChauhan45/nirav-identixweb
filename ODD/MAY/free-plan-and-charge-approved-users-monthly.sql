WITH main_data AS (
    SELECT 
        ac.store_name,
        ac.action,
        ac.page,
        ac.created_at,
        cs.created_on
    FROM admin_user_activity ac
    JOIN client_store cs 
        ON ac.store_name = cs.store_name
    WHERE 
        CONVERT_TZ(ac.created_at, '+00:00', '+05:30') BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        AND cs.shop_plan NOT IN (
            'Development', 'Staff', 'Developer Preview', 'Trial',
            'Shopify Plus Partner Sandbox', 'affiliate',
            'partner_test', 'plus_partner_sandbox',
            'Pause and Build', 'Staff Business',
            'fraudulent', 'Canceled', 'Frozen',
            'Fraudulent', 'cancelled', 'frozen'
        )
        AND cs.shop_plan NOT LIKE '%Development%'
        AND cs.plan_display_name NOT LIKE '%Development%'
),

fresh_installs AS (
    SELECT 
        md.store_name,
        MAX(md.created_at) AS created_at
    FROM main_data md
    WHERE 
        md.action IN (
            'fresh_install',
            'Fresh installs',
            'Fresh Installs',
            'reinstall',
            'Re-installs',
            'reopen',
            'store re-opened'
        )
        AND CONVERT_TZ(md.created_on, '+00:00', '+05:30') 
            BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        AND NOT EXISTS (
            SELECT 1
            FROM admin_user_activity u
            WHERE u.store_name = md.store_name
              AND (
                    u.action IN (
                        'uninstall',
                        'Paid uninstalled',
                        'Store closed'
                    )
                    OR u.page = 'uninstall'
                  )
              AND u.created_at > md.created_at
              AND CONVERT_TZ(u.created_at, '+00:00', '+05:30') 
                    BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        )
    GROUP BY md.store_name
),

free_plan_actions AS (
    SELECT
        ft.store_name
    FROM fresh_installs ft
    JOIN admin_user_activity fp
        ON fp.store_name = ft.store_name
        AND fp.action = 'Free Plan'
        AND CONVERT_TZ(fp.created_at, '+00:00', '+05:30') BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
       AND NOT EXISTS (
            SELECT 1
            FROM admin_user_activity ca
            WHERE ca.store_name = fp.store_name	
              AND ca.action = 'Charge Approved'
              AND CONVERT_TZ(ca.created_at, '+00:00', '+05:30') >= CONVERT_TZ(fp.created_at, '+00:00', '+05:30')
              AND CONVERT_TZ(ca.created_at, '+00:00', '+05:30') BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
       )
    GROUP BY ft.store_name
),

paid_plan_actions AS (
    SELECT
        ft.store_name,
        ft.created_at AS fresh_install_date,
        MAX(ac.created_at) AS latest_charge_approved
    FROM fresh_installs ft
    JOIN admin_user_activity ac
        ON ft.store_name = ac.store_name
    WHERE ac.action = 'Charge Approved'
      AND CONVERT_TZ(ac.created_at, '+00:00', '+05:30')
            BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
    GROUP BY
        ft.store_name,
        ft.created_at
    HAVING MAX(ac.created_at) > ft.created_at
)

SELECT 
    (SELECT COUNT(DISTINCT store_name) FROM free_plan_actions) AS `Free Plan Users`,
    (SELECT COUNT(DISTINCT store_name) FROM paid_plan_actions) AS `Charge Approved`,
    (SELECT COUNT(DISTINCT store_name) FROM fresh_installs) AS `Total Fresh Installs`;
