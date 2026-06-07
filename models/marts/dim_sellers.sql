-- dim_sellers.sql
-- PURPOSE: Seller dimension table enriched with performance metrics.
--          One row per seller. Powers the "Seller Performance" dashboard.

with seller_metrics as (

    select * from {{ ref('int_seller_metrics__grouped') }}

),

geolocation as (

    select
        zip_code_prefix,
        latitude,
        longitude

    from {{ ref('stg_olist__geolocation') }}

),

final as (

    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['s.seller_id']) }}
                                                    as seller_key,

        -- Natural key
        s.seller_id,

        -- Location
        s.seller_city,
        s.seller_state,
        s.zip_code_prefix,
        g.latitude                                  as seller_latitude,
        g.longitude                                 as seller_longitude,

        -- Volume metrics
        s.total_orders,
        s.total_items_sold,
        s.distinct_products,

        -- Revenue metrics
        s.total_revenue,
        s.avg_item_price,
        s.total_freight_revenue,

        -- Delivery performance
        s.delivered_orders,
        s.on_time_deliveries,
        s.on_time_rate_pct,
        s.avg_delay_days,

        -- Customer satisfaction
        s.avg_review_score,
        s.review_count,

        -- Composite score
        s.seller_score,

        -- Seller tier based on composite score
        case
            when s.seller_score >= 80 then 'top_performer'
            when s.seller_score >= 60 then 'good'
            when s.seller_score >= 40 then 'average'
            else 'needs_improvement'
        end                                         as seller_tier,

        -- Timeline
        s.first_sale_at,
        s.most_recent_sale_at,
        datediff('day', s.first_sale_at, s.most_recent_sale_at)
                                                    as seller_tenure_days

    from seller_metrics s
    left join geolocation g on s.zip_code_prefix = g.zip_code_prefix

)

select * from final
