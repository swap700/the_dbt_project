-- fct_revenue_daily.sql
-- PURPOSE: Daily revenue summary — the model that powers trend charts in Tableau.
-- GRAIN: One row per calendar day
-- WHY A SEPARATE MODEL: Pre-aggregating to daily grain makes Tableau fast
--                       even with 100k+ orders. Avoids row-level scans on every load.

with orders as (

    -- Only count delivered orders in revenue (exclude canceled, processing, etc.)
    select *
    from {{ ref('int_orders__joined') }}
    where is_delivered = true

),

daily_metrics as (

    select
        date_trunc('day', purchased_at)::date       as revenue_date,

        -- Volume
        count(order_id)                             as orders_count,
        sum(item_count)                             as items_sold,

        -- Revenue
        sum(order_gross_revenue)                    as gross_revenue,
        sum(items_subtotal)                         as product_revenue,
        sum(freight_total)                          as freight_revenue,
        avg(order_gross_revenue)                    as avg_order_value,

        -- Payment mix
        count(case when primary_payment_type = 'credit_card' then 1 end)
                                                    as credit_card_orders,
        count(case when primary_payment_type = 'boleto' then 1 end)
                                                    as boleto_orders,
        count(case when primary_payment_type = 'voucher' then 1 end)
                                                    as voucher_orders,

        -- Customer satisfaction
        avg(review_score)                           as avg_review_score,
        count(case when is_positive_review then 1 end)
                                                    as positive_reviews,

        -- Delivery performance
        count(case when is_late_delivery then 1 end) as late_deliveries,
        avg(delivery_delay_days)                    as avg_delay_days

    from orders
    group by 1

),

-- Add running totals for trend analysis
with_cumulative as (

    select
        revenue_date,
        orders_count,
        items_sold,
        gross_revenue,
        product_revenue,
        freight_revenue,
        avg_order_value,
        credit_card_orders,
        boleto_orders,
        voucher_orders,
        avg_review_score,
        positive_reviews,
        late_deliveries,
        avg_delay_days,

        -- 7-day rolling average revenue (smooths daily spikes for trend lines)
        round(
            avg(gross_revenue) over (
                order by revenue_date
                rows between 6 preceding and current row
            ), 2
        )                                           as revenue_7d_avg,

        -- Month-to-date revenue
        sum(gross_revenue) over (
            partition by date_trunc('month', revenue_date)
            order by revenue_date
        )                                           as revenue_mtd,

        -- Cumulative all-time revenue
        sum(gross_revenue) over (
            order by revenue_date
        )                                           as revenue_cumulative

    from daily_metrics

)

select * from with_cumulative
order by revenue_date
