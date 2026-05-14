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

installed_at_month_end AS (

    SELECT
        mla.store_client_id,
        mla.month,
        a.created_at AS install_created_at
    FROM monthly_last_action mla
    JOIN admin_user_activity a
        ON a.store_client_id = mla.store_client_id
       AND a.created_at = mla.last_created_at

    WHERE a.action IN (
        'fresh install','fresh installs','fresh_install',
        'reinstall','re-installs','re installs','re_install'
    )

),

same_month_completed AS (

    SELECT DISTINCT
        store_client_id,
        DATE_FORMAT(created_at, '%Y-%m') AS MONTH
    FROM admin_user_activity
    WHERE ACTION IN (
        'Onboarding—completed',
        'Onboarding completed',
        'onboarding completed'
    )

),

excluded_stores AS (

    SELECT DISTINCT
        store_client_id
    FROM client_store
    WHERE shop_plan IN (
        'Development','Staff','Developer Preview','Trial',
        'Shopify Plus Partner Sandbox','affiliate','partner_test',
        'plus_partner_sandbox','Pause and Build',
        'fraudulent', 'Canceled', 'Frozen',
        'Fraudulent', 'cancelled', 'frozen'
    )

)
SELECT
    t.month,
    COUNT(DISTINCT CASE
        WHEN oc_same.store_client_id IS NOT NULL
        THEN t.store_client_id
    END) AS completed_same_month
FROM installed_at_month_end t
LEFT JOIN same_month_completed oc_same
    ON oc_same.store_client_id = t.store_client_id
   AND oc_same.month = t.month
WHERE t.store_client_id NOT IN (
    SELECT store_client_id
    FROM excluded_stores
) AND t.month <= '2026-04'
GROUP BY t.month
ORDER BY t.month;