-- stg_olist__order_items.sql
-- PURPOSE: Clean the order items grain (one row per item in an order).
-- KEY DECISIONS:
--   - total_item_revenue = price + freight_value (what the customer paid for this line)
--   - Surrogate key built from order_id + order_item_id (the natural composite PK)

with source as (

    select * from {{ source('olist_raw', 'order_items') }}

),

renamed as (

    select
        -- Composite natural key (no single PK column in raw)
        {{ dbt_utils.generate_surrogate_key(['order_id', 'order_item_id']) }}
                                                            as order_item_key,

        -- Keys
        order_id,
        order_item_id,
        product_id,
        seller_id,

        -- Timestamps
        try_to_timestamp(shipping_limit_date)               as shipping_limit_at,

        -- Financials (raw is already in BRL, keep as-is)
        price::float                                        as item_price,
        freight_value::float                                as freight_value,
        (price::float + freight_value::float)               as total_item_revenue

    from source

)

select * from renamed
