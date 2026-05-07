WITH fresh_installs AS (
    SELECT 
        ac.store_name,
        MAX(ac.created_at) AS created_at
    FROM admin_user_activity ac

    JOIN client_store cs
        ON ac.store_name = cs.store_name
    
    WHERE ac.action IN (
        'fresh_install', 'Fresh installs', 'Fresh Installs',
        'reinstall', 'Re-installs', 'reopen',
        'store re-opened'
    )
    
    AND CONVERT_TZ(ac.created_at, '+00:00', '+05:30') 
        BETWEEN '2026-01-01 00:00:00'
            AND '2026-02-28 23:59:59'

    AND CONVERT_TZ(cs.created_on, '+00:00', '+05:30') 
        BETWEEN '2026-01-01 00:00:00'
            AND '2026-02-28 23:59:59'

    AND NOT EXISTS (
        SELECT 1
        FROM admin_user_activity u
        WHERE u.store_name = ac.store_name
          AND (
                u.action IN (
                    'uninstall', 'Paid uninstalled', 'Store closed'
                )
                OR u.page = 'uninstall'
              )
          AND u.created_at > ac.created_at
          AND CONVERT_TZ(u.created_at, '+00:00', '+05:30') 
                BETWEEN '2026-01-01 00:00:00'
                    AND '2026-02-28 23:59:59'
    )

    AND cs.shop_plan NOT IN (
        'Development', 'Staff', 'Developer Preview', 'Trial',
        'Shopify Plus Partner Sandbox', 'affiliate', 'partner_test',
        'plus_partner_sandbox', 'Pause and Build', 'Staff Business',
        'fraudulent', 'Canceled', 'Frozen', 'Fraudulent', 'cancelled',
        'frozen'
    )

    AND cs.shop_plan NOT LIKE '%Development%'
    AND cs.plan_display_name NOT LIKE '%Development%'

    GROUP BY ac.store_name
),
re_installs AS (
    SELECT
        ac.store_name,
        MAX(ac.created_at) AS created_at
    FROM admin_user_activity ac
    JOIN client_store cs
        ON ac.store_name = cs.store_name
    WHERE ac.action IN (
        'reinstall', 'Re-installs'
    )
    AND CONVERT_TZ(ac.created_at, '+00:00', '+05:30')
        BETWEEN '2026-01-01 00:00:00' AND '2026-02-28 23:59:59'
    AND CONVERT_TZ(cs.created_on, '+00:00', '+05:30') < '2026-01-01 00:00:00' 
    
    -- Exclude stores that later uninstalled within the same range
    AND NOT EXISTS (
        SELECT 1
        FROM admin_user_activity u
        WHERE u.store_name = ac.store_name
          AND (
              u.action IN ('uninstall', 'Paid uninstalled', 'Store closed')
              OR u.page = 'uninstall'
          )
          AND u.created_at > ac.created_at
          AND CONVERT_TZ(u.created_at, '+00:00', '+05:30')
              BETWEEN '2026-01-01 00:00:00' AND '2026-02-28 23:59:59'
    )
    AND cs.shop_plan NOT IN (
        'Development', 'Staff', 'Developer Preview', 'Trial',
        'Shopify Plus Partner Sandbox', 'affiliate', 'partner_test',
        'plus_partner_sandbox', 'Pause and Build', 'Staff Business',
        'fraudulent', 'Canceled', 'Frozen', 'Fraudulent', 'cancelled',
        'frozen'
    )
    AND cs.shop_plan        NOT LIKE '%Development%'
    AND cs.plan_display_name NOT LIKE '%Development%'
    GROUP BY ac.store_name
),
reopen_count AS (
    SELECT
        ac.store_name,
        MAX(ac.created_at) AS created_at
    FROM admin_user_activity ac
    JOIN client_store cs
        ON ac.store_name = cs.store_name
        
    WHERE
	DATE(CONVERT_TZ(ac.created_at, '+00:00', '+05:30')) BETWEEN '2026-01-01 00:00:00' AND '2026-02-28 23:59:59'
	AND DATE(CONVERT_TZ(cs.created_on, '+00:00', '+05:30')) < '2026-01-01 00:00:00'
	AND LOWER(ac.action) IN ('reopen', 'store re-opened', 'store re-opened')
	AND NOT EXISTS (
                 SELECT 1
                 FROM admin_user_activity u
                 WHERE u.store_name = ac.store_name
                   AND DATE(CONVERT_TZ(u.created_at, '+00:00', '+05:30')) BETWEEN '2026-01-01 00:00:00' AND '2026-02-28 23:59:59'
                   AND u.created_at = (
                       SELECT MAX(u2.created_at)
                       FROM admin_user_activity u2
                       WHERE u2.store_name = ac.store_name
                         AND DATE(CONVERT_TZ(u2.created_at, '+00:00', '+05:30')) BETWEEN '2026-01-01 00:00:00' AND '2026-02-28 23:59:59'
                   )
                   AND u.action IN ('Store closed', 'uninstall', 'Paid uninstalled')
             )
	 
    AND cs.shop_plan NOT IN (
        'Development', 'Staff', 'Developer Preview', 'Trial',
        'Shopify Plus Partner Sandbox', 'affiliate', 'partner_test',
        'plus_partner_sandbox', 'Pause and Build', 'Staff Business',
        'fraudulent', 'Canceled', 'Frozen', 'Fraudulent', 'cancelled',
        'frozen'
    )
    AND cs.shop_plan        NOT LIKE '%Development%'
    AND cs.plan_display_name NOT LIKE '%Development%'
    GROUP BY ac.store_name
),
f_count AS (
	SELECT DATE_FORMAT(CONVERT_TZ(created_at, '+00:00', '+05:30'),'%Y-%m') AS MONTH, COUNT(*) AS fresh_count FROM fresh_installs GROUP BY MONTH
),
re_install_count AS (
	SELECT DATE_FORMAT(CONVERT_TZ(created_at, '+00:00', '+05:30'),'%Y-%m') AS MONTH, COUNT(*) AS re_installs_count FROM re_installs GROUP BY MONTH
),
re_open_count AS (
	SELECT DATE_FORMAT(CONVERT_TZ(created_at, '+00:00', '+05:30'),'%Y-%m') AS MONTH, COUNT(*) AS re_open_count FROM reopen_count GROUP BY MONTH
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

