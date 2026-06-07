-- int_orders__joined.sql
-- PURPOSE: Join orders with items, payments, and reviews to produce
--          one enriched row per order with all key metrics pre-computed.
-- MATERIALIZATION: ephemeral (inlined as a CTE — no table created)
-- WHY HERE: This logic is reused by both fct_orders AND fct_revenue_daily.
--           Centralizing it means a single place to fix if logic changes.

with orders as (

    select * from {{ ref('stg_olist__orders') }}

),

-- Aggregate items to order level
order_items_agg as (

    select
        order_id,
        count(*)                        as item_count,
        sum(item_price)                 as items_subtotal,
        sum(freight_value)              as freight_total,
        sum(total_item_revenue)         as order_gross_revenue,
        count(distinct seller_id)       as distinct_sellers

    from {{ ref('stg_olist__order_items') }}
    group by 1

),

-- Aggregate payments to order level
-- (sum all payment methods, take the primary payment type)
order_payments_agg as (

    select
        order_id,
        sum(payment_amount)             as total_payment_amount,
        max(payment_installments)       as max_installments,
        -- Primary payment = the one with highest sequential number
        max_by(payment_type, payment_sequential) as primary_payment_type

    from {{ ref('stg_olist__order_payments') }}
    group by 1

),

-- One review per order (take the latest if duplicates exist)
order_reviews_deduped as (

    select
        order_id,
        review_score,
        review_title,
        review_message,
        review_created_at,
        response_time_hours

    from {{ ref('stg_olist__order_reviews') }}
    qualify row_number() over (
        partition by order_id
        order by review_created_at desc
    ) = 1

),

joined as (

    select
        -- Order keys & status
        o.order_id,
        o.customer_id,
        o.order_status,

        -- Timestamps
        o.purchased_at,
        o.approved_at,
        o.delivered_to_carrier_at,
        o.delivered_to_customer_at,
        o.estimated_delivery_at,

        -- Delivery metrics
        o.actual_delivery_days,
        o.estimated_delivery_days,
        o.delivery_delay_days,
        case when o.delivery_delay_days > 0 then true else false end
                                                as is_late_delivery,

        -- Item metrics (COALESCE to 0: ~775 orders have no items in raw data — Olist quirk)
        coalesce(oi.item_count, 0)          as item_count,
        coalesce(oi.items_subtotal, 0)      as items_subtotal,
        coalesce(oi.freight_total, 0)       as freight_total,
        coalesce(oi.order_gross_revenue, 0) as order_gross_revenue,
        coalesce(oi.distinct_sellers, 0)    as distinct_sellers,

        -- Payment metrics
        op.total_payment_amount,
        op.max_installments,
        op.primary_payment_type,

        -- Review metrics (nullable — not all orders have reviews)
        r.review_score,
        r.review_title,
        r.review_message,
        r.response_time_hours               as review_response_hours,

        -- Convenience flags
        case when o.order_status = 'delivered' then true else false end
                                                as is_delivered,
        case when r.review_score >= 4 then true else false end
                                                as is_positive_review

    from orders o
    left join order_items_agg oi    on o.order_id = oi.order_id
    left join order_payments_agg op on o.order_id = op.order_id
    left join order_reviews_deduped r on o.order_id = r.order_id

)

select * from joined
