WITH raw_installs AS (
    SELECT
        ac.store_name,
        cs.store_client_id,
        ac.action,
        ac.created_at,
        ROW_NUMBER() OVER (
            PARTITION BY cs.store_client_id
            ORDER BY ac.created_at ASC
        ) AS rnk
    FROM admin_user_activity ac
    JOIN client_store cs
        ON ac.store_name = cs.store_name
    WHERE ac.action IN (
        'fresh_install', 'Fresh installs', 'Fresh Installs',
        'reinstall', 'Re-installs',
        'reopen', 'store re-opened'
    )
    AND CONVERT_TZ(ac.created_at, '+00:00', '+05:30')
        BETWEEN '2026-01-01 00:00:00' AND '2026-01-31 23:59:59'
    AND CONVERT_TZ(cs.created_on, '+00:00', '+05:30')
        BETWEEN '2026-01-01 00:00:00' AND '2026-01-31 23:59:59'
    
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
              BETWEEN '2026-01-01 00:00:00' AND '2026-01-31 23:59:59'
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

install_counts AS (
    SELECT
        store_client_id,
        store_name,
        
        -- First event per store = fresh install
        COUNT(CASE WHEN rnk = 1 THEN 1 END) AS fresh_install_count,
        
        -- All subsequent events = reinstalls
        COUNT(CASE WHEN rnk > 1 THEN 1 END) AS reinstall_count
    FROM raw_installs
    GROUP BY store_client_id, store_name
),

store_wise_count AS (
    SELECT
        store_client_id,
        store_name,
        fresh_install_count,
        reinstall_count,
        (fresh_install_count + reinstall_count) AS total_install_count,
        CASE
            WHEN reinstall_count = 0 THEN 'Fresh Only'
            WHEN fresh_install_count = 0 THEN 'Reinstall Only'
            ELSE 'Reinstall'
        END AS install_type
    FROM install_counts
    ORDER BY total_install_count DESC
)

-- SELECT * FROM store_wise_count where reinstall_count=1;
SELECT * FROM store_wise_count;