WITH latest_action AS (
    SELECT
        ac.store_client_id,
        MAX(ac.created_at) AS created_at
    FROM admin_user_activity ac
    JOIN client_store cs
        ON cs.store_client_id = ac.store_client_id
    WHERE LOWER(ac.action) IN (
        'fresh install', 'fresh installs', 'fresh_install', 'reinstall',
        're-installs', 're installs', 're_install', 'uninstall'
    )
 

    -- same month
    AND DATE(ac.created_at) BETWEEN '2026-04-01' AND '2026-04-30'

    
    /* 
    -- Overall count
    AND DATE(cs.created_at) < '2026-04-01'
    */
    GROUP BY ac.store_client_id
),

classified_actions AS (
    SELECT
        z.store_client_id,
        z.created_at,
        CASE
            WHEN LOWER(z.action) IN (
                'fresh install', 'fresh installs', 'fresh_install'
            )
            AND z.page = 'Fresh Installs page'
            THEN 'fresh'

            WHEN LOWER(z.action) IN (
                'reinstall', 're-installs', 're installs', 're_install'
            )
            AND LOWER(z.page) = 're-installs'
            THEN 'reinstall'
        END AS action_type
    FROM latest_action la
    JOIN admin_user_activity z
        ON z.store_client_id = la.store_client_id
       AND z.created_at = la.created_at
    WHERE
        LOWER(z.action) IN (
            'fresh install', 'fresh installs', 'fresh_install'
        )
        OR (
            LOWER(z.action) IN (
                'reinstall', 're-installs', 're installs', 're_install'
            )
            AND LOWER(z.page) = 're-installs'
        )
),

trial_converted AS (
    SELECT
        ca.store_client_id,
        ca.created_at,
        ca.action_type
    FROM classified_actions ca
    JOIN admin_user_activity ft
        ON ft.store_client_id = ca.store_client_id
       AND LOWER(ft.action) = 'plan upgraded'
       AND ft.created_at >= ca.created_at
),

filtered_store AS (
    SELECT
        tc.store_client_id,
        tc.created_at,
        tc.action_type
    FROM trial_converted tc
    LEFT JOIN client_store cs
        ON cs.store_client_id = tc.store_client_id
    WHERE (
        cs.shop_plan NOT IN (
            'Development', 'Staff', 'Developer Preview', 'Trial', 'Shopify Plus Partner Sandbox', 'affiliate', 'partner_test',
            'plus_partner_sandbox', 'Pause and Build', 'fraudulent', 'Canceled', 'Frozen', 'Fraudulent', 'cancelled', 'frozen'
        )
        OR cs.shop_plan IS NULL
    )
)

SELECT COUNT(DISTINCT store_client_id) AS paid_install_count FROM filtered_store;