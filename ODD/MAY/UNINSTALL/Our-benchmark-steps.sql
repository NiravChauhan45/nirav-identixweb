WITH latest_uninstall AS(
    SELECT
        a.store_name
    FROM admin_user_activity a
    JOIN client_store cs 
        ON cs.store_name = a.store_name
    WHERE
        DATE(CONVERT_TZ(a.created_at, '+00:00', '+05:30')) BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        AND (
            (a.action IN ('uninstall', 'Paid uninstalled'))
            OR (a.page = 'uninstall')
            OR a.action = 'Store closed'
        )
        /* Install exists in date range */
        AND EXISTS (
            SELECT 1
            FROM admin_user_activity install_ev
            WHERE install_ev.store_name = a.store_name
              AND install_ev.action IN ('fresh_install','Fresh Installs')
              AND DATE(CONVERT_TZ(install_ev.created_at, '+00:00', '+05:30')) BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        )
        /* Last uninstall in range */
        AND a.created_at = (
            SELECT MAX(u.created_at)
            FROM admin_user_activity u
            WHERE u.store_name = a.store_name
              AND (
                    (u.action IN ('uninstall', 'Paid uninstalled'))
                    OR (u.page = 'uninstall')
                  )
              AND DATE(CONVERT_TZ(u.created_at, '+00:00', '+05:30')) BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        )
        /* Install and uninstall in same month */
        AND EXISTS (
            SELECT 1
            FROM admin_user_activity install_month_check
            WHERE install_month_check.store_name = a.store_name
              AND install_month_check.action IN ('fresh_install','Fresh Installs')
              AND DATE_FORMAT(CONVERT_TZ(install_month_check.created_at, '+00:00', '+05:30'),
                    '%Y-%m'
                  ) = DATE_FORMAT(
                    CONVERT_TZ(a.created_at, '+00:00', '+05:30'),
                    '%Y-%m'
                  )
              AND DATE(CONVERT_TZ(install_month_check.created_at, '+00:00', '+05:30')) BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
        )

        /* No reinstall after uninstall */
        AND NOT EXISTS (
            SELECT 1
            FROM admin_user_activity later
            WHERE later.store_name = a.store_name
              AND later.created_at > a.created_at
              AND DATE(CONVERT_TZ(later.created_at, '+00:00', '+05:30')) BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
              AND later.action IN (
                    'install', 'fresh_install', 'Fresh Installs', 'reinstall', 'Re-installs')
        )

        /* Plan exclusions */
        AND cs.shop_plan NOT IN (
            'Development', 'Staff', 'Developer Preview', 'Trial',
            'Shopify Plus Partner Sandbox', 'affiliate', 'partner_test',
            'plus_partner_sandbox', 'Staff Business'
        )

        AND (
            cs.plan_display_name IS NULL
            OR cs.plan_display_name NOT IN (
                'Development','Staff','Developer Preview','Trial',
                'Shopify Plus Partner Sandbox','affiliate','staff',
                'partner_test','trial','plus_partner_sandbox','Staff Business'
            )
        )

        AND (
            cs.plan_display_name IS NULL
            OR cs.plan_display_name NOT LIKE '%Development%'
        )

    AND cs.shop_plan NOT LIKE '%Development%'
    GROUP BY a.store_name
),
main_data AS (
    SELECT
        ac.store_name,
        DATE_FORMAT(CONVERT_TZ(ac.created_at, '+00:00', '+05:30'), '%Y-%m') AS MONTH,
        MAX(CASE WHEN LOWER(ac.action) IN ('uninstall', 'app_uninstall') THEN ac.created_at END) AS last_uninstall_time,
        MAX(CASE WHEN LOWER(ac.action) IN ('fresh_install', 'reinstall', 'fresh installs', 're-installs', 'install') THEN ac.created_at END) AS last_install_reinstall,
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'app enabled-odd'               THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS app_enabled,
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'calendar placement (default)'  THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS calendar_placement,
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'delivery method enabled'       THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS delivery_method_enabled,
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'date-picker — enabled'         THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS date_picker_enabled,
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'time-picker — enabled'         THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS time_picker_enabled,
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'google maps api key added'     THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS google_maps_api_key_added,
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'checkout widget enabled'       THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS checkout_widget_enabled,
        CASE WHEN SUM(CASE WHEN LOWER(ac.action) = 'scheduled order placed'        THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS scheduled_order_placed

    FROM latest_uninstall lu
    JOIN admin_user_activity ac
    ON lu.store_name = ac.store_name
    WHERE CONVERT_TZ(ac.created_at, '+00:00', '+05:30') BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
    GROUP BY ac.store_name, DATE_FORMAT(CONVERT_TZ(ac.created_at, '+00:00', '+05:30'), '%Y-%m')  
)
SELECT
    m.month,
    
    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
         AND m.app_enabled = 1
        THEN m.store_name
    END) AS app_enabled,
    
    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
         AND m.calendar_placement = 1
        THEN m.store_name
    END) AS calendar_placement,

    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
        AND m.delivery_method_enabled = 1
        THEN m.store_name
    END) AS delivery_method_enabled,

    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
        AND m.date_picker_enabled = 1
        THEN m.store_name
    END) AS date_picker_enabled,

    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
        AND m.time_picker_enabled = 1
        THEN m.store_name
    END) AS time_picker_enabled,

    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
        AND m.google_maps_api_key_added = 1
        THEN m.store_name
    END) AS google_maps_api_key_added,

    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
        AND m.checkout_widget_enabled = 1
        THEN m.store_name
    END) AS checkout_widget_enabled,

    COUNT(DISTINCT CASE
        WHEN m.last_uninstall_time > m.last_install_reinstall
        AND m.scheduled_order_placed = 1
        THEN m.store_name
    END) AS scheduled_order_placed

FROM main_data m
GROUP BY m.month
ORDER BY m.month;