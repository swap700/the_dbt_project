-- dim_customers.sql
-- PURPOSE: Customer dimension table for BI joins.
--          One row per REAL customer (customer_unique_id).
-- WHY customer_unique_id and NOT customer_id:
--   Olist creates a new customer_id for each order. Using customer_id as
--   the dim PK would mean one "customer" per order — wrong for CLV analysis.
--   customer_unique_id is the stable identity across all orders.

with customer_metrics as (

    select * from {{ ref('int_customer_orders__grouped') }}

),

-- Add geo coordinates for mapping visualizations
geolocation as (

    select
        zip_code_prefix,
        latitude,
        longitude

    from {{ ref('stg_olist__geolocation') }}

),

final as (

    select
        -- Primary key for this dimension
        {{ dbt_utils.generate_surrogate_key(['c.customer_unique_id']) }}
                                                    as customer_key,

        -- Natural key
        c.customer_unique_id,

        -- Location
        c.customer_city,
        c.customer_state,
        c.zip_code_prefix,
        g.latitude                                  as customer_latitude,
        g.longitude                                 as customer_longitude,

        -- Order history
        c.total_orders,
        c.delivered_orders,
        c.first_order_at,
        c.most_recent_order_at,
        c.customer_tenure_days,

        -- CLV metrics
        c.lifetime_revenue,
        c.avg_order_value,
        c.min_order_value,
        c.max_order_value,

        -- Satisfaction
        c.avg_review_score,
        c.avg_delivery_delay_days,

        -- Segmentation
        c.customer_segment,

        -- CLV tier (for dashboard filter)
        case
            when c.lifetime_revenue >= 1000 then 'high_value'
            when c.lifetime_revenue >= 200  then 'mid_value'
            else 'low_value'
        end                                         as clv_tier,

        -- Is this an active customer? (ordered in last 6 months of dataset)
        case
            when c.most_recent_order_at >= dateadd('month', -6, current_date) then true
            else false
        end                                         as is_active

    from customer_metrics c
    left join geolocation g on c.zip_code_prefix = g.zip_code_prefix

)

select * from final
