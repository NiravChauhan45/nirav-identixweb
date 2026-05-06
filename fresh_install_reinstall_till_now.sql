WITH fresh_installs_till_now AS (
    SELECT 
        cs.store_client_id,
        ac.store_name,
        ac.created_at
    FROM admin_user_activity ac
    JOIN client_store cs
        ON ac.store_name = cs.store_name
    
    WHERE ac.action IN (
        'fresh_install','Fresh installs','Fresh Installs',
        'reinstall','Re-installs',
        'reopen','store re-opened'
    )
    AND CONVERT_TZ(ac.created_at, '+00:00', '+05:30') 
        BETWEEN '2026-01-01 00:00:00' AND NOW()
    AND CONVERT_TZ(cs.created_on, '+00:00', '+05:30') 
        BETWEEN '2026-01-01 00:00:00' AND NOW()

    AND NOT EXISTS (
        SELECT 1
        FROM admin_user_activity u
        WHERE u.store_name = ac.store_name
          AND (
                u.action IN ('uninstall','Paid uninstalled','Store closed')
                OR u.page = 'uninstall'
              )
          AND u.created_at > ac.created_at
          AND CONVERT_TZ(u.created_at, '+00:00', '+05:30') 
                BETWEEN '2026-01-01 00:00:00' AND NOW()
    )

    AND cs.shop_plan NOT IN (
        'Development','Staff','Developer Preview','Trial',
        'Shopify Plus Partner Sandbox','affiliate','partner_test',
        'plus_partner_sandbox','Pause and Build','Staff Business',
        'fraudulent','Canceled','Frozen','Fraudulent','cancelled','frozen'
    )
    AND cs.shop_plan NOT LIKE '%Development%'
    AND cs.plan_display_name NOT LIKE '%Development%'
),
re_installs AS (
    SELECT
         cs.store_client_id,
	 ac.store_name,
	 ac.created_at
    FROM admin_user_activity ac
    JOIN client_store cs
        ON ac.store_name = cs.store_name
    WHERE ac.action IN (
        'reinstall', 'Re-installs'
    )
    AND CONVERT_TZ(ac.created_at, '+00:00', '+05:30')
        BETWEEN '2026-01-01 00:00:00' AND NOW()
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
              BETWEEN '2026-01-01 00:00:00' AND NOW()
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
),

fresh_install_count AS(
	SELECT store_client_id, store_name 
	FROM fresh_installs_till_now 
	WHERE created_at BETWEEN '2026-01-01' AND '2026-01-31'
	GROUP BY store_client_id, store_name
),
re_install_count AS(
	SELECT store_client_id, store_name 
	FROM re_installs 
	WHERE created_at BETWEEN '2026-01-01' AND '2026-01-31'
	GROUP BY store_client_id, store_name
)


-- Check only for count
-- select count(*) as fresh_count from fresh_install_count
-- SELECT COUNT(*) AS re_install_count FROM re_install_count


-- Check Row wise data
SELECT * FROM fresh_install_count;
-- select * from re_install_count;