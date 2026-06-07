-- int_customer_orders__grouped.sql
-- PURPOSE: Group all order-level data to the TRUE customer level
--          (using customer_unique_id) to enable CLV calculations.
-- WHY HERE: CLV is computed in intermediate, not staging, because it
--           requires joining back through orders — multi-table logic
--           belongs in intermediate, not in a staging model.

with customers as (

    select * from {{ ref('stg_olist__customers') }}

),

-- Get the unique customer identifier for each order
order_customers as (

    select
        o.order_id,
        o.purchased_at,
        o.is_delivered,
        o.order_gross_revenue,
        o.review_score,
        o.delivery_delay_days,
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        c.zip_code_prefix

    from {{ ref('int_orders__joined') }} o
    inner join customers c on o.customer_id = c.customer_id

),

-- Aggregate to TRUE customer level
customer_metrics as (

    select
        customer_unique_id,

        -- Location (use most recent order's location)
        max_by(customer_city, purchased_at)     as customer_city,
        max_by(customer_state, purchased_at)    as customer_state,
        max_by(zip_code_prefix, purchased_at)   as zip_code_prefix,

        -- Order counts
        count(order_id)                         as total_orders,
        count(case when is_delivered then 1 end) as delivered_orders,

        -- Revenue = Customer Lifetime Value
        sum(order_gross_revenue)                as lifetime_revenue,
        avg(order_gross_revenue)                as avg_order_value,
        min(order_gross_revenue)                as min_order_value,
        max(order_gross_revenue)                as max_order_value,

        -- Timeline
        min(purchased_at)                       as first_order_at,
        max(purchased_at)                       as most_recent_order_at,
        datediff('day', min(purchased_at), max(purchased_at))
                                                as customer_tenure_days,

        -- Satisfaction
        avg(review_score)                       as avg_review_score,
        avg(delivery_delay_days)                as avg_delivery_delay_days,

        -- Segmentation flags
        case when count(order_id) = 1 then 'one_time'
             when count(order_id) between 2 and 3 then 'occasional'
             else 'repeat'
        end                                     as customer_segment

    from order_customers
    group by 1

)

select * from customer_metrics
