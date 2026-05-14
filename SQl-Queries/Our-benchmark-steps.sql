WITH main_data AS(
    SELECT
        ac.store_client_id,
        DATE_FORMAT(ac.created_at, '%Y-%m') AS MONTH,
        
        MAX(CASE WHEN LOWER(ac.action) IN ('uninstall', 'app_uninstall') THEN ac.created_at END) AS last_uninstall_time,
        MAX(CASE WHEN LOWER(ac.action) IN ('fresh_install', 'reinstall', 'fresh installs', 're-installs','install') THEN ac.created_at END) AS last_install_reinstall,
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'App enabled-odd' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS app_enabled,
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'Calendar Placement (Default)' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS calendar_placement,        
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'Delivery Method Enabled' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS delivery_method_enabled,        
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'Date-picker — Enabled' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS date_picker_enabled,        
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'Time-picker — Enabled' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS time_picker_enabled,        
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'Google Maps API Key Added' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS google_maps_api_key_added,        
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'Checkout Widget Enabled' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS checkout_widget_enabled,        
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'Scheduled Order Placed' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS scheduled_order_placed
    FROM admin_user_activity ac
    JOIN client_store cs
      ON cs.store_client_id = ac.store_client_id
     AND DATE_FORMAT(cs.created_on, '%Y-%m') = DATE_FORMAT(ac.created_at, '%Y-%m')
     AND cs.shop_plan NOT IN (
        'Development','Staff','Developer Preview','Trial',
        'Shopify Plus Partner Sandbox','affiliate','staff',
        'partner_test','trial','plus_partner_sandbox', 'Basic App Development'
    )
    AND cs.plan_display_name NOT IN (
        'Development','Staff','Developer Preview','Trial',
        'Shopify Plus Partner Sandbox','affiliate','staff',
        'partner_test','trial','plus_partner_sandbox', 'Basic App Development'
    )
    WHERE DATE(ac.created_at) BETWEEN '2026-03-01' AND '2026-03-31'
    GROUP BY ac.store_client_id, MONTH
)
SELECT
    m.month,
    
    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
         AND m.app_enabled = 1
        THEN m.store_client_id
    END) AS app_enabled,
    
    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
         AND m.calendar_placement = 1
        THEN m.store_client_id
    END) AS calendar_placement,

    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
        AND m.delivery_method_enabled = 1
        THEN m.store_client_id
    END) AS delivery_method_enabled,

    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
        AND m.date_picker_enabled = 1
        THEN m.store_client_id
    END) AS date_picker_enabled,

    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
        AND m.time_picker_enabled = 1
        THEN m.store_client_id
    END) AS time_picker_enabled,

    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
        AND m.google_maps_api_key_added = 1
        THEN m.store_client_id
    END) AS google_maps_api_key_added,

    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
        AND m.checkout_widget_enabled = 1
        THEN m.store_client_id
    END) AS checkout_widget_enabled,

    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
        AND m.scheduled_order_placed = 1
        THEN m.store_client_id
    END) AS scheduled_order_placed
FROM main_data m
GROUP BY m.month
ORDER BY m.month;
