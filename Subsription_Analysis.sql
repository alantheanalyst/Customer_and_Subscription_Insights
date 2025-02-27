-- 1 Number of Foodie-Fi customers
SELECT 
COUNT(DISTINCT customer_id) total_customers
FROM subscriptions

-- 2. Monthly distribution of trial plans
SELECT 
COUNT(plan_id) plan_count, 
MONTH(start_date) month
FROM subscriptions
WHERE plan_id = 0
GROUP BY MONTH(start_date)
ORDER BY month

-- 3. Number of customers suscribed to each plan afer 2020
;WITH cte AS (
SELECT
plan_name, 
s.plan_id, 
start_date
FROM subscriptions s
JOIN plans p
	ON s.plan_id = p.plan_id
WHERE YEAR(start_date) > '2020'
)
SELECT COUNT(plan_name) AS plan_count_2021, plan_name, plan_id
FROM cte
WHERE plan_id in (0, 1, 2, 3, 4, 5)
GROUP BY 
plan_name,
plan_id
ORDER BY plan_id

-- 4. Number of % of customers who churned
SELECT 
COUNT(*) AS churn_count, 
CAST(100.0 * COUNT(*) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions) AS float) AS churn_percent
FROM subscriptions
WHERE plan_id = 4

-- 5. Number and % of customers who churned after their free trials
;WITH ranking AS (
SELECT
customer_id, 
plan_id, 
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY plan_id) rank
FROM subscriptions 
)
SELECT 
COUNT(*) as trial_to_chrun_count,
(100 * COUNT(*) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions)) as '%'
FROM ranking
WHERE plan_id = 4 AND rank = 2

--6. What is the number and percentage of customer plans after their initial free trial?
;WITH next_plan AS (
SELECT customer_id, plan_id,
LEAD(plan_id, 1) OVER(PARTITION BY customer_id ORDER BY plan_id)  AS plan_after_trial
FROM subscriptions
)
SELECT plan_after_trial,
COUNT(*) AS conversions, CAST(100 * COUNT(*) / (SELECT COUNT(DISTINCT customer_id)
FROM subscriptions) AS float) AS percentage
FROM next_plan
WHERE plan_after_trial IS NOT NULL
GROUP BY plan_after_trial
ORDER BY plan_after_trial 

-- 7. Customer count and percentage of all subscriptions at 2020-21-31
;WITH plans_2020 AS (
SELECT 
customer_id, 
s.plan_id, plan_name, 
start_date,
LEAD(start_date, 1) OVER(PARTITION BY customer_id ORDER BY start_date) next_date
FROM subscriptions s JOIN plans p
ON s.plan_id = p.plan_id
WHERE start_date <= '2020-12-31'
),
plans_2021 AS (
SELECT 
plan_id, 
plan_name, 
COUNT(DISTINCT customer_id) AS customers_per_plan
FROM plans_2020
WHERE  next_date IS NOT NULL AND (start_date  < '2020-12-31' AND next_date > '2020-12-31') OR
	(next_date IS NULL AND start_date  < '2020-12-31')
GROUP BY plan_id, plan_name
)
SELECT 
plan_name, 
customers_per_plan, 
CAST(100.0 * customers_per_plan / (SELECT COUNT(DISTINCT customer_id) 
FROM subscriptions) AS float) AS '%'
FROM plans_2021
GROUP BY plan_id, plan_name, customers_per_plan
ORDER BY plan_id

-- 8. Customers who upgraded to an annual plan in 2020.
SELECT COUNT(*) annual_plan_count
FROM subscriptions
WHERE plan_id = 3 AND YEAR(start_date) = '2020'

-- 9. Average time it took a customer to upgrade to an annual plan
;WITH trial_plans AS (
SELECT customer_id, start_date AS trial_date
FROM subscriptions
WHERE plan_id = 0
),
annual_plans AS (
SELECT customer_id, start_date AS annual_date
FROM subscriptions
WHERE plan_id = 3
)
SELECT AVG(DATEDIFF(DAY, trial_date, annual_date)) AS avg_days_until_upgrade
FROM trial_plans tp JOIN annual_plans ap
ON tp.customer_id = ap.customer_id

--10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
;WITH  trial_plans AS (
SELECT customer_id, start_date AS trial_date
FROM subscriptions
WHERE plan_id = 0
),
annual_plan AS (
SELECT customer_id, start_date AS annual_date
FROM subscriptions
WHERE plan_id = 3
),
buckets AS (
SELECT tp.customer_id, trial_date, annual_date, 
DATEDIFF(DAY, trial_date, annual_date) / 30 + 1 AS bucket
FROM trial_plans tp JOIN annual_plan ap
ON tp.customer_id = ap.customer_id
)
SELECT 
CASE
	WHEN bucket = 1 THEN CONCAT(bucket - 1, '-', bucket * 30, ' days')
	ELSE CONCAT((bucket - 1) * 30 + 1, '-', bucket * 30, ' days')
END AS period,
COUNT(customer_id) AS total_customers
FROM buckets
GROUP BY bucket

-- 11. Customers who downgraded from a pro-monthly to a basic monthly plan in 2020
;WITH next_plan_cte AS (
SELECT customer_id, plan_id, start_date, 
LEAD(plan_id, 1) OVER(PARTITION BY customer_id ORDER BY plan_id) AS next_plan
FROM subscriptions
)
SELECT COUNT(*) AS downgraded
FROM next_plan_cte
WHERE YEAR(start_date) = '2020' AND plan_id = 2 AND next_plan = 1
