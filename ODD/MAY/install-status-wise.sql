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

re_installs AS (
    SELECT
        md.store_name,
        MAX(md.created_at) AS created_at
    FROM main_data md
    WHERE 
        md.action IN ('reinstall', 'Re-installs')
        AND CONVERT_TZ(md.created_on, '+00:00', '+05:30') < '2026-05-01 00:00:00'
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

reopen_count AS (
    SELECT
        md.store_name,
        MAX(md.created_at) AS created_at
    FROM main_data md
    WHERE 
        LOWER(md.action) IN ('reopen', 'store re-opened')
        AND CONVERT_TZ(md.created_on, '+00:00', '+05:30') < '2026-05-01 00:00:00'
        AND NOT EXISTS (
            SELECT 1 FROM admin_user_activity u
            WHERE u.store_name = md.store_name
              AND CONVERT_TZ(u.created_at, '+00:00', '+05:30') 
                  BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
              AND u.created_at = (
                  SELECT MAX(u2.created_at)
                  FROM admin_user_activity u2
                  WHERE u2.store_name = md.store_name
                    AND CONVERT_TZ(u2.created_at, '+00:00', '+05:30') 
                        BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
              )
              AND u.action IN ('Store closed', 'uninstall', 'Paid uninstalled')
        )
    GROUP BY md.store_name
)

SELECT
    (SELECT COUNT(*) FROM fresh_installs) AS fresh_install_count,
    (SELECT COUNT(*) FROM re_installs) AS reinstall_count,
    (SELECT COUNT(*) FROM reopen_count) AS reopen_count;
