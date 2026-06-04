SELECT
    COUNT(DISTINCT CASE
        WHEN (cs.charge_approve = '0' OR cs.charge_approve = '2')
             AND cs.status = '1'
        THEN cs.store_client_id
    END) AS free_plan_active_merchants,

    COUNT(DISTINCT CASE
        WHEN cs.charge_approve = '1'
             AND cs.status = '1'
        THEN cs.store_client_id
    END) AS paid_plan_active_merchants
FROM client_store cs
JOIN admin_user_activity ac
    ON cs.store_name = ac.store_name

WHERE cs.shop_plan NOT IN (
    'Development', 'Staff', 'Developer Preview', 'Trial',
    'Shopify Plus Partner Sandbox', 'affiliate', 'partner_test',
    'plus_partner_sandbox', 'Pause and Build', 'fraudulent',
    'Canceled', 'Frozen', 'Fraudulent', 'cancelled', 'frozen'
)
AND ac.action IN (
   'fresh_install', 'Fresh installs', 'Fresh Installs',
   'reinstall', 'Re-installs', 'reopen', 'store re-opened'
)
AND NOT EXISTS (
    SELECT 1
    FROM admin_user_activity u
    WHERE cs.store_name = u.store_name
    AND(u.action IN('uninstall', 'Paid uninstalled', 'Store closed') OR u.page = 'uninstall')
    AND cs.created_on < '2026-05-01 00:00:00' 
)
AND cs.created_on < '2026-05-01 00:00:00';