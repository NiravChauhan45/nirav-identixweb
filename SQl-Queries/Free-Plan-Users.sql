WITH last_monthly_action AS (
    SELECT
        ac.store_client_id,
        DATE_FORMAT(ac.created_at, '%Y-%m') AS MONTH,
        MAX(ac.created_at) AS last_created
    FROM admin_user_activity ac
    JOIN client_store cs
        ON ac.store_name = cs.store_name

    WHERE ACTION IN (
        'fresh install','fresh installs','fresh_install',
        'reinstall','re-installs','re installs','re_install',
        'uninstall'
    )

 
    -- same month
    AND ac.created_at >= '2026-03-01'
    AND ac.created_at < DATE_ADD('2026-03-31', INTERVAL 1 DAY)
    
    /*
    -- Overall Count
    AND cs.created_at < '2026-03-01'
    */
   
    GROUP BY
        ac.store_client_id,
        DATE_FORMAT(ac.created_at, '%Y-%m')
),

install_actions AS (
    SELECT
        lma.store_client_id,
        lma.month,
        a.created_at,
        CASE
            WHEN a.action IN (
                'fresh install','fresh installs','fresh_install'
            ) THEN 'fresh'

            WHEN a.action IN (
                'reinstall','re-installs','re installs','re_install'
            ) THEN 'reinstall'
        END AS action_type
    FROM last_monthly_action lma
    JOIN admin_user_activity a
        ON a.store_client_id = lma.store_client_id
       AND a.created_at = lma.last_created
    WHERE a.action IN (
        'fresh install','fresh installs','fresh_install',
        'reinstall','re-installs','re installs','re_install'
    )
),

trial_actions AS (
    SELECT
        ia.store_client_id,
        ia.month,
        ia.created_at,
        ia.action_type,
        ft.created_at AS free_trial_created
    FROM install_actions ia
    JOIN admin_user_activity ft
        ON ft.store_client_id = ia.store_client_id
       AND ft.action IN ('Free User', 'Plan Downgraded')
       AND ft.created_at >= ia.created_at
),

filtered_trials AS (
    SELECT
        ta.*
    FROM trial_actions ta
    WHERE NOT EXISTS (
        SELECT 1
        FROM admin_user_activity ca
        WHERE ca.store_client_id = ta.store_client_id
          AND ca.action = 'Plan Upgraded'
          AND ca.created_at >= ta.free_trial_created
          AND DATE_FORMAT(ca.created_at, '%Y-%m') = ta.month
    )
    AND NOT EXISTS (
        SELECT 1
        FROM client_store cs
        WHERE cs.store_client_id = ta.store_client_id
          AND cs.shop_plan IN (
              'Development', 'Staff', 'Developer Preview', 'Trial', 'Shopify Plus Partner Sandbox',
              'affiliate', 'partner_test', 'plus_partner_sandbox', 'Pause and Build', 'fraudulent',
              'Canceled', 'Frozen', 'Fraudulent', 'cancelled', 'frozen'
          )
    )
)

SELECT COUNT(DISTINCT store_client_id) AS free_install_count FROM filtered_trials

/*
SELECT
    month,
    COUNT(DISTINCT CASE
        WHEN action_type = 'fresh'
        THEN store_client_id
    END) AS fresh_install_with_trial,

    COUNT(DISTINCT CASE
        WHEN action_type = 'reinstall'
        THEN store_client_id
    END) AS reinstall_with_trial

FROM filtered_trials
GROUP BY month
ORDER BY month;

*/