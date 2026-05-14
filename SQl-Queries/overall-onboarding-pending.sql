WITH monthly_last_action AS (
    SELECT
        cs.store_client_id,
        DATE_FORMAT(ac.created_at, '%Y-%m') AS MONTH,
        MAX(ac.created_at) AS last_created_at
    FROM admin_user_activity ac
    JOIN client_store cs
    ON ac.store_name = cs.store_name
    WHERE ac.ACTION IN (
        'fresh install', 'fresh installs', 'fresh_install', 'reinstall', 're-installs', 're installs', 're_install', 'uninstall'
    )

    AND DATE(cs.created_on) < '2026-04-01'
    GROUP BY cs.store_client_id, DATE_FORMAT(ac.created_at, '%Y-%m')
),


installed_stores AS (
    SELECT
        mla.store_client_id,
        mla.month,
        a.created_at AS install_created_at,
        a.action
    FROM monthly_last_action mla
    JOIN admin_user_activity a
        ON a.store_client_id = mla.store_client_id
       AND a.created_at = mla.last_created_at
    WHERE a.action IN (
        'fresh install', 'fresh installs', 'fresh_install', 'reinstall', 're-installs', 're installs', 're_install'
    )
),
filtered_stores AS (
    SELECT
        t.*
    FROM installed_stores t
    WHERE NOT EXISTS (
        SELECT 1
        FROM client_store cs
        WHERE cs.store_client_id = t.store_client_id
          AND cs.shop_plan IN (
                'Development', 'Staff', 'Developer Preview', 'Trial', 'Shopify Plus Partner Sandbox', 'affiliate', 'partner_test',
                'plus_partner_sandbox', 'Pause and Build', 'fraudulent', 'Canceled', 'Frozen', 'Fraudulent', 'cancelled',
                'frozen'	
          )
    )
),

same_month_completed AS (
    SELECT
        t.store_client_id,
        t.month
    FROM installed_stores t
    JOIN admin_user_activity oc
    ON oc.store_client_id = t.store_client_id
    AND oc.action IN('Onboarding—completed', 'Onboarding completed', 'onboarding completed')
    AND DATE_FORMAT(oc.created_at, '%Y-%m') = t.month
    GROUP BY t.store_client_id, t.month
)

SELECT
    fs.month,
    COUNT(
        DISTINCT CASE
            WHEN smc.store_client_id IS NULL
            THEN fs.store_client_id
        END
    ) AS pending_in_month

FROM filtered_stores fs
LEFT JOIN same_month_completed smc
       ON smc.store_client_id = fs.store_client_id
      AND smc.month = fs.month
WHERE fs.month <= '2026-04'
GROUP BY fs.month
ORDER BY fs.month;