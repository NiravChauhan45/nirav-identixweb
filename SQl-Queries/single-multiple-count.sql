WITH install_counts AS (
	SELECT
	   ac.store_name,
	   cs.store_client_id,
	   COUNT(*) AS install_count
	FROM admin_user_activity ac
	JOIN client_store cs
	    ON ac.store_name = cs.store_name
	    
	WHERE ac.action IN (
	    'fresh_install','Fresh installs','Fresh Installs',
	    'reinstall','Re-installs',
	    'reopen','store re-opened'
	)
	AND CONVERT_TZ(ac.created_at, '+00:00', '+05:30') BETWEEN '2026-01-01 00:00:00' AND '2026-01-31 23:59:59'
	AND CONVERT_TZ(cs.created_on, '+00:00', '+05:30') BETWEEN '2026-01-01 00:00:00' AND '2026-01-31 23:59:59'

	-- exclude stores having uninstall in same range
	AND NOT EXISTS (
	    SELECT 1
	    FROM admin_user_activity u
	    WHERE u.store_name = ac.store_name
	      AND (
		    u.action IN ('uninstall','Paid uninstalled','Store closed')
		    OR u.page = 'uninstall'
		  )
		  AND u.created_at > ac.created_at
	      AND CONVERT_TZ(u.created_at, '+00:00', '+05:30') BETWEEN '2026-01-01 00:00:00' AND '2026-01-31 23:59:59'
	)

	AND cs.shop_plan NOT IN (
		'Development','Staff','Developer Preview','Trial',
		'Shopify Plus Partner Sandbox','affiliate','partner_test',
		'plus_partner_sandbox','Pause and Build','Staff Business', 'fraudulent', 'Canceled', 'Frozen', 'Fraudulent', 'cancelled', 'frozen'
	    )
	    AND cs.shop_plan NOT LIKE '%Development%'
	    AND cs.plan_display_name NOT LIKE '%Development%'
	GROUP BY cs.store_client_id
), 
store_wise_count AS (
	SELECT
	    store_client_id,
	    store_name,
	    install_count,
	    CASE 
		WHEN install_count = 1 THEN 'Single Count In Month'
		WHEN install_count > 1 THEN 'Multiple Count In Month'
	    END AS install_type
	FROM install_counts
	ORDER BY install_count
),
total_counts AS (
	SELECT 
	   COUNT(CASE WHEN install_count = 1 THEN 1 END) AS `Single Count In Month`, 
	   COUNT(CASE WHEN install_count > 1 THEN 1 END) AS `Multiple Count In Month` 
	FROM install_counts
)

-- select * from store_wise_count;
SELECT * FROM total_counts