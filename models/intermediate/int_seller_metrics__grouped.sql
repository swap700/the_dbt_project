-- int_seller_metrics__grouped.sql
-- PURPOSE: Compute seller performance metrics aggregated from order items
--          and reviews. Used to populate dim_sellers.
-- SELLER SCORE logic:
--   A composite score (0–100) weighted:
--     40% avg review score (normalized to 0–100)
--     40% on-time delivery rate
--     20% order volume (log-normalized, capped at 100)

with sellers as (

    select * from {{ ref('stg_olist__sellers') }}

),

-- Get order items and join back to the order level for status/review
seller_orders as (

    select
        oi.seller_id,
        oi.order_id,
        oi.product_id,
        oi.item_price,
        oi.freight_value,
        oi.total_item_revenue,
        o.purchased_at,
        o.is_delivered,
        o.delivery_delay_days,
        o.review_score

    from {{ ref('stg_olist__order_items') }} oi
    inner join {{ ref('int_orders__joined') }} o on oi.order_id = o.order_id

),

seller_metrics as (

    select
        seller_id,

        -- Volume
        count(distinct order_id)                            as total_orders,
        count(*)                                            as total_items_sold,
        count(distinct product_id)                          as distinct_products,

        -- Revenue
        sum(total_item_revenue)                             as total_revenue,
        avg(item_price)                                     as avg_item_price,
        sum(freight_value)                                  as total_freight_revenue,

        -- Delivery performance
        count(case when is_delivered then 1 end)            as delivered_orders,
        sum(case when delivery_delay_days <= 0 then 1 else 0 end)
                                                            as on_time_deliveries,
        avg(delivery_delay_days)                            as avg_delay_days,

        -- Calculated on-time rate
        round(
            sum(case when delivery_delay_days <= 0 then 1.0 else 0.0 end)
            / nullif(count(distinct order_id), 0) * 100,
            2
        )                                                   as on_time_rate_pct,

        -- Customer satisfaction
        avg(review_score)                                   as avg_review_score,
        count(review_score)                                 as review_count,

        -- Seller score (composite 0–100)
        round(
            (coalesce(avg(review_score), 3) / 5.0 * 100 * 0.40)   -- 40% from rating
            + (round(
                sum(case when delivery_delay_days <= 0 then 1.0 else 0.0 end)
                / nullif(count(distinct order_id), 0) * 100, 2
              ) * 0.40)                                             -- 40% on-time
            + (least(ln(count(distinct order_id) + 1) / ln(1000) * 100, 100) * 0.20),  -- 20% volume
            2
        )                                                   as seller_score,

        -- Timeline
        min(purchased_at)                                   as first_sale_at,
        max(purchased_at)                                   as most_recent_sale_at

    from seller_orders
    group by 1

)

select
    s.seller_id,
    s.seller_city,
    s.seller_state,
    s.zip_code_prefix,
    m.total_orders,
    m.total_items_sold,
    m.distinct_products,
    m.total_revenue,
    m.avg_item_price,
    m.total_freight_revenue,
    m.delivered_orders,
    m.on_time_deliveries,
    m.avg_delay_days,
    m.on_time_rate_pct,
    m.avg_review_score,
    m.review_count,
    m.seller_score,
    m.first_sale_at,
    m.most_recent_sale_at

from sellers s
left join seller_metrics m on s.seller_id = m.seller_id
