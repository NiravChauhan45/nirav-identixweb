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
            BETWEEN '2026-01-01 00:00:00' AND '2026-02-28 23:59:59'
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
            BETWEEN '2026-01-01 00:00:00' AND '2026-02-28 23:59:59'
        AND NOT EXISTS (
            SELECT 1 FROM admin_user_activity u
            WHERE u.store_name = md.store_name
              AND (
                  u.action IN ('uninstall', 'Paid uninstalled', 'Store closed')
                  OR u.page = 'uninstall'
              )
              AND u.created_at > md.created_at
              AND CONVERT_TZ(u.created_at, '+00:00', '+05:30') 
                  BETWEEN '2026-01-01 00:00:00' AND '2026-02-28 23:59:59'
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
        AND CONVERT_TZ(md.created_on, '+00:00', '+05:30') < '2026-01-01 00:00:00'
        AND NOT EXISTS (
            SELECT 1 FROM admin_user_activity u
            WHERE u.store_name = md.store_name
              AND (
                  u.action IN ('uninstall', 'Paid uninstalled', 'Store closed')
                  OR u.page = 'uninstall'
              )
              AND u.created_at > md.created_at
              AND CONVERT_TZ(u.created_at, '+00:00', '+05:30') 
                  BETWEEN '2026-01-01 00:00:00' AND '2026-02-28 23:59:59'
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
        AND CONVERT_TZ(md.created_on, '+00:00', '+05:30') < '2026-01-01 00:00:00'
        AND NOT EXISTS (
            SELECT 1 FROM admin_user_activity u
            WHERE u.store_name = md.store_name
              AND CONVERT_TZ(u.created_at, '+00:00', '+05:30') 
                  BETWEEN '2026-01-01 00:00:00' AND '2026-02-28 23:59:59'
              AND u.created_at = (
                  SELECT MAX(u2.created_at)
                  FROM admin_user_activity u2
                  WHERE u2.store_name = md.store_name
                    AND CONVERT_TZ(u2.created_at, '+00:00', '+05:30') 
                        BETWEEN '2026-01-01 00:00:00' AND '2026-02-28 23:59:59'
              )
              AND u.action IN ('Store closed', 'uninstall', 'Paid uninstalled')
        )
    GROUP BY md.store_name
),
f_count AS (
    SELECT 
        DATE_FORMAT(CONVERT_TZ(created_at, '+00:00', '+05:30'), '%Y-%m') AS MONTH, 
        COUNT(*) AS fresh_count 
    FROM fresh_installs 
    GROUP BY MONTH
),
re_install_count AS (
    SELECT 
        DATE_FORMAT(CONVERT_TZ(created_at, '+00:00', '+05:30'), '%Y-%m') AS MONTH, 
        COUNT(*) AS re_installs_count 
    FROM re_installs 
    GROUP BY MONTH
),
re_open_count AS (
    SELECT 
        DATE_FORMAT(CONVERT_TZ(created_at, '+00:00', '+05:30'), '%Y-%m') AS MONTH, 
        COUNT(*) AS re_open_count 
    FROM reopen_count 
    GROUP BY MONTH
)
SELECT
    f.month,
    f.fresh_count,          
    re_in.re_installs_count,
    re_open.re_open_count
FROM f_count AS f
JOIN re_install_count AS re_in
    ON f.month = re_in.month
JOIN re_open_count AS re_open
    ON f.month = re_open.month;
