SELECT
  active_users,
  paid_users,
  free_users,
  app_status,
  DATE_FORMAT(last_month_date, '%Y-%m') AS MONTH
FROM
  monthly_allover_data
WHERE
  DATE_FORMAT(last_month_date, '%Y-%m') = '2026-03'
ORDER BY
  id DESC
LIMIT
  1;