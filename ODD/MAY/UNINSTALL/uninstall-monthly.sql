WITH main_data AS (
	SELECT    
	   cs.store_client_id,
	   a.store_name,
	    a.action,
	    a.created_at,
	    a.page,
	    cs.created_on

	FROM admin_user_activity a
	JOIN client_store cs
	    ON cs.store_name = a.store_name

	WHERE
	    DATE(CONVERT_TZ(a.created_at, '+00:00', '+05:30'))
		  BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
	    AND (
		(a.action IN ('uninstall', 'Paid uninstalled')) 
		OR (a.page = 'uninstall') 
		OR a.action = 'Store closed'
	    )
	    
	    AND NOT EXISTS (
		SELECT 1
		FROM admin_user_activity later
		WHERE later.store_name = a.store_name
		  AND later.created_at > a.created_at
		  AND DATE(CONVERT_TZ(later.created_at, '+00:00', '+05:30'))
			BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
		  AND later.action IN ('install','fresh_install','Fresh Installs','reinstall','Re-installs')
	    )

	    /* Plan exclusions */
	    AND cs.shop_plan NOT IN (
			'Development','Staff','Developer Preview','Trial',
			'Shopify Plus Partner Sandbox','affiliate','staff',
			'partner_test','trial','plus_partner_sandbox', 'Staff Business',
			'cancelled','frozen'
	    ) 
	    AND (
			cs.plan_display_name IS NULL
			OR cs.plan_display_name NOT IN (
				'Development','Staff','Developer Preview','Trial',
				'Shopify Plus Partner Sandbox','affiliate','staff',
				'partner_test','trial','plus_partner_sandbox', 'Staff Business'
		)
	    )
	    AND (
		cs.plan_display_name IS NULL
		OR cs.plan_display_name NOT LIKE '%Development%'
	    )
	    AND cs.shop_plan NOT LIKE '%Development%'
		AND cs.email NOT LIKE '%@identixweb.in' AND cs.email NOT LIKE '%@elookinto.org'
),
same_month AS (
	SELECT
	   md.store_client_id,
	   md.store_name
	FROM main_data md
	WHERE 
	   md.action IN('uninstall', 'Paid uninstalled')
	   AND DATE(CONVERT_TZ(md.created_on, '+00:00', '+05:30')) BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
	   GROUP BY md.store_client_id, md.store_name
),
previous_month AS(
	SELECT
	   md.store_client_id,
	   md.store_name
	FROM main_data md
	WHERE 
	   md.action IN('uninstall', 'Paid uninstalled', 'UNINSTALLED')
	   AND DATE(CONVERT_TZ(md.created_on, '+00:00', '+05:30')) < '2026-05-01 00:00:00'
	GROUP BY md.store_client_id, md.store_name
),
reinstall_unistall AS(
	SELECT
	   md.store_client_id,
	   md.store_name
	FROM main_data md
	WHERE 
	   md.action IN('uninstall', 'Paid uninstalled', 'UNINSTALLED')
	   AND DATE(CONVERT_TZ(md.created_on, '+00:00', '+05:30')) < '2026-05-01'
	   AND EXISTS (
                SELECT 1
                FROM admin_user_activity rei
                WHERE rei.store_name = md.store_name
                  AND rei.action IN ('reinstall','Re-installs')
                  AND DATE(CONVERT_TZ(rei.created_at, '+00:00', '+05:30'))
                        BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
                  )
	GROUP BY md.store_client_id, md.store_name
),
store_closed AS(
	SELECT
	   md.store_client_id,
	   md.store_name
	FROM main_data md
	WHERE 
	   md.action IN('Store closed')
	   AND NOT EXISTS (
                SELECT 1
                FROM admin_user_activity reopen
                WHERE reopen.store_name = md.store_name
                AND LOWER(reopen.action) IN (
                    'reopen',
                    'store re-opened'
                )
            AND reopen.created_at > md.created_at
            )
	GROUP BY md.store_client_id, md.store_name
)

SELECT
    (SELECT COUNT(*) FROM same_month) AS same_month,
    (SELECT COUNT(*) FROM previous_month) AS previous_month,
    (SELECT COUNT(*) FROM reinstall_unistall) AS reinstall_unistall,
    (SELECT COUNT(*) FROM store_closed) AS store_closed;
