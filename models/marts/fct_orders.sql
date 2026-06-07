-- fct_orders.sql
-- PURPOSE: The primary fact table. One row per order.
--          This is what Tableau connects to for order-level analysis.
-- GRAIN: One row per order_id
-- RELATIONSHIPS: Joins to dim_customers (via customer_unique_id) and dim_sellers
--                is handled at the BI layer — this table is pre-aggregated to order grain.

with orders_joined as (

    select * from {{ ref('int_orders__joined') }}

),

customers as (

    select
        customer_id,
        customer_unique_id,
        customer_city,
        customer_state

    from {{ ref('stg_olist__customers') }}

),

final as (

    select
        -- Surrogate key for the fact table
        {{ dbt_utils.generate_surrogate_key(['o.order_id']) }}  as order_key,

        -- Natural keys (for joining to dims)
        o.order_id,
        o.customer_id,
        c.customer_unique_id,

        -- Order metadata
        o.order_status,
        o.is_delivered,
        o.is_late_delivery,

        -- Dates (truncated for easy dashboard filtering)
        o.purchased_at,
        date_trunc('day', o.purchased_at)       as purchase_date,
        date_trunc('month', o.purchased_at)     as purchase_month,
        date_trunc('year', o.purchased_at)      as purchase_year,
        o.delivered_to_customer_at,

        -- Location (customer's state — useful for geographic analysis)
        c.customer_city,
        c.customer_state,

        -- Order metrics
        o.item_count,
        o.distinct_sellers,
        o.items_subtotal,
        o.freight_total,
        o.order_gross_revenue,
        o.total_payment_amount,
        o.primary_payment_type,
        o.max_installments,

        -- Delivery metrics
        o.actual_delivery_days,
        o.estimated_delivery_days,
        o.delivery_delay_days,

        -- Review metrics
        o.review_score,
        o.is_positive_review,
        o.review_response_hours

    from orders_joined o
    left join customers c on o.customer_id = c.customer_id

)

select * from final
