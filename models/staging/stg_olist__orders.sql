-- stg_olist__orders.sql
-- PURPOSE: Clean and type-cast the raw orders table.
-- KEY DECISIONS:
--   - Cast all timestamp strings to proper TIMESTAMP type
--   - Compute delivery_days_actual and delivery_days_estimate as derived columns
--     (handy for downstream metrics, cheap to compute here once)

with source as (

    select * from {{ source('olist_raw', 'orders') }}

),

renamed as (

    select
        -- Keys
        order_id,
        customer_id,

        -- Status
        lower(trim(order_status))                                   as order_status,

        -- Timestamps (cast from string → proper timestamp)
        try_to_timestamp(order_purchase_timestamp)                  as purchased_at,
        try_to_timestamp(order_approved_at)                         as approved_at,
        try_to_timestamp(order_delivered_carrier_date)              as delivered_to_carrier_at,
        try_to_timestamp(order_delivered_customer_date)             as delivered_to_customer_at,
        try_to_timestamp(order_estimated_delivery_date)             as estimated_delivery_at,

        -- Derived: how many days from purchase to actual delivery?
        datediff(
            'day',
            try_to_timestamp(order_purchase_timestamp),
            try_to_timestamp(order_delivered_customer_date)
        )                                                           as actual_delivery_days,

        -- Derived: how many days was the customer promised?
        datediff(
            'day',
            try_to_timestamp(order_purchase_timestamp),
            try_to_timestamp(order_estimated_delivery_date)
        )                                                           as estimated_delivery_days,

        -- Derived: was the order delivered early (negative = early, positive = late)?
        datediff(
            'day',
            try_to_timestamp(order_estimated_delivery_date),
            try_to_timestamp(order_delivered_customer_date)
        )                                                           as delivery_delay_days

    from source

)

select * from renamed
