use diner;

-- Amount & Time Spent per Customer
select 
a.customer_id,
sum(b.price) as 'Total Sales',
count(distinct a.order_date) as 'Total Visits'
from sales a join menu b 
on a.product_id = b.product_id
group by a.customer_id;


-- First item purchased by each customer
select distinct
a.customer_id,
b.product_name,
a.order_date
from (select 
customer_id,
order_date, 
product_id, 
dense_rank() over(partition by customer_id order by order_date) as rank 
from sales) a join menu b 
on a.product_id = b.product_id
where a.rank = 1;

-- Most popular item
select 
b.product_name
from (
select 
product_id,
dense_rank() over(order by count(product_id) desc) as rank
from sales
group by product_id
) a join menu b 
on a.product_id = b.product_id
where rank = 1;

-- Ramen Purchases per Customer
with ramen_cte as (
select product_id
from menu
where product_id = 3
)
select 
b.customer_id,
count(a.product_id) as ramen_count
from ramen_cte a join sales b 
on a.product_id = b.product_id
group by b.customer_id;

-- Most popular item per customer

with item_cte as (
select distinct
a.customer_id,
b.product_name,
dense_rank() over(partition by customer_id order by count(a.product_id) desc) as rank
from sales a join menu b
on a.product_id = b.product_id
group by a.customer_id, b.product_name
)
select 
customer_id,
product_name 
from item_cte
where rank = 1

-- First purchases pre and post-membership

with pre_membership_cte as (
select
a.customer_id,
c.product_name,
dense_rank() over(partition by a.customer_id order by a.order_date) as rank
from sales a join members b
on a.customer_id = b.customer_id
join menu c
on a.product_id = c.product_id
where a.order_date < b.join_date
), post_membership_cte as (
select 
a.customer_id,
c.product_name,
dense_rank() over(partition by a.customer_id order by a.order_date) as rank
from sales a join members b
on a.customer_id = b.customer_id
join menu c
on a.product_id = c.product_id
where a.order_date > b.join_date
)
select 
a.customer_id,
a.product_name as 'first products before membership',
b.customer_id as member_id,
b.product_name as 'first products post-membership'
from pre_membership_cte a join post_membership_cte b
on a.customer_id = b.customer_id 
where a.rank = 1
and b.rank = 1

-- Number of items purchased and amount spent before membersips
select 
a.customer_id,
count(a.product_id) as 'number of items',
sum(b.price) as 'total sales'
from (
select 
b.customer_id,
a.product_id
from sales a join members b
on a.customer_id = b.customer_id
where a.order_date < b.join_date
) a join menu b 
on a.product_id = b.product_id
group by a.customer_id;


-- Points Earned per Customer
select 
a.customer_id,
sum(
case
	when a.product_id = 1 then b.price * 20
	else b.price * 10
end) as points
from sales a join menu b 
on a.product_id = b.product_id
group by a.customer_id;

-- Points earned by customers at the end of January
select 
a.customer_id as member_id,
sum(
case 
	when b.product_id = 1 then c.price * 20
	when b.order_date between a.join_date and a.day_7 then c.price * 20
	else c.price * 10
end) as points
from (
select 
customer_id,
join_date,
dateadd(day, 6, join_date) as day_7
from members
) a join sales b 
on a.customer_id = b.customer_id
join menu c
on b.product_id = c.product_id
where month(b.order_date) = 1
group by a.customer_id;
