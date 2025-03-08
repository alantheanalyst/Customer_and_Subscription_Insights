use foodie_fi

-- Number of Foodie-Fi customers
select 
count(distinct customer_id) 'Number of Customers'
from subscriptions;

-- Monthly distribution of trial plans
select 
month(b.start_date) as month,
count(a.plan_id) as 'number of plans'
from (select plan_id from plans where plan_id = 0) a join subscriptions b
on a.plan_id = b.plan_id
group by month(b.start_date)
order by month

-- Number of customers suscribed per plan post-2020
select 
b.plan_name,
count(a.customer_id) as 'number of customers'
from (select plan_id, customer_id from subscriptions where year(start_date) > 2020) a join plans b
on a.plan_id = b.plan_id
group by b.plan_name


-- Number of % of customers who churned
select 
count(b.customer_id) as 'number of customers',
100 * count(b.customer_id) / (select count(distinct customer_id) from subscriptions) as 'percent of customers'
from (select plan_id from plans where plan_id = 4) a join subscriptions b
on a.plan_id = b.plan_id;

-- Number and % of customers who churned after their free trials
with trial_to_churn_cte as (
select 
customer_id,
plan_id,
row_number() over(partition by customer_id order by plan_id) as plan_rank
from subscriptions
)
select
count(customer_id) as 'number of customers',
100 * count(customer_id) / (select count(distinct customer_id) from subscriptions) as 'percent of customers'
from trial_to_churn_cte
where plan_id = 4 and plan_rank = 2;

-- Number and percentage of customers per plan after free trial
with next_plan_cte as (
select 
customer_id,
plan_id ,
lead(plan_id, 1) over(partition by customer_id order by plan_id) plan_after_trail
from subscriptions
)
select 
b.plan_name,
count(a.customer_id) as conversions,
100 * count(a.customer_id) / (select count(distinct customer_id) from subscriptions) as percentage
from (select * from next_plan_cte where plan_after_trail is not null) a join plans b
on a.plan_after_trail = b.plan_id
group by b.plan_name;

-- Total and percentage of customers per plan at 2020-21-31
with plans_2020_cte as (
select 
a.customer_id,
b.plan_id,
b.plan_name,
a.start_date,
lead(a.start_date, 1) over(partition by a.customer_id order by a.start_date) as next_date
from (select * from subscriptions where start_date <= '2020-12-31') a join plans b 
on a.plan_id = b.plan_id
), plans_2021 as (
select 
plan_id,
plan_name,
count(distinct customer_id) as 'number of customers',
100 * count(distinct customer_id) / (select count(distinct customer_id) from subscriptions) as 'percent of customers'
from plans_2020_cte 
where next_date is not null 
and (start_date  < '2020-12-31' and next_date > '2020-12-31') 
or (next_date is null and start_date < '2020-12-31')
group by plan_id, plan_name
)
select 
plan_name,
[number of customers],
[percent of customers]
from plans_2021
order by plan_id

-- Customers who upgraded to an annual plan in 2020
select count(customer_id) as 'number of customers'
from subscriptions
where plan_id = 3 
and year(start_date) = 2020

-- Average time it took a customer to upgrade to an annual plan

with trial_cte as (
select 
customer_id,
start_date as trial_date
from subscriptions
where plan_id = 0
), annual_cte as (
select 
customer_id,
start_date as annual_date
from subscriptions
where plan_id = 3
)
select 
avg(datediff(day, trial_date, annual_date)) as 'average days until upgrade'
from trial_cte a join annual_cte b
on a.customer_id = b.customer_id;

-- Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
with  trial_cte as (
select 
customer_id, 
start_date as trial_date
from subscriptions
where plan_id = 0
),
annual_date as (
select customer_id, 
start_date as annual_date
from subscriptions
where plan_id = 3
),
buckets as (
select a.customer_id, 
a.trial_date, 
b.annual_date, 
datediff(day, trial_date, annual_date) / 30 + 1 as bucket
from trial_cte a JOIN annual_date b
on a.customer_id = b.customer_id
)
select 
case
	when bucket = 1 then concat(bucket - 1, '-', bucket * 30, ' days')
	else concat((bucket - 1) * 30 + 1, '-', bucket * 30, ' days')
end as period,
count(customer_id) AS total_customers
from buckets
group by bucket;

-- Customers who downgraded from a pro-monthly to a basic monthly plan in 2020
with next_plan_cte as (
select 
customer_id,
plan_id,
start_date,
lead(plan_id, 1) over(partition by customer_id order by plan_id) as next_plan
from subscriptions
)
select count(a.customer_id) as 'number of customers who downgraded'
from next_plan_cte a join (select 
plan_id 
from 
next_plan_cte 
where year(start_date) = 2020  and plan_id = 2 and next_plan = 1) b 
on a.plan_id = b.plan_id


