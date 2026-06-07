-- stg_olist__order_payments.sql
-- PURPOSE: Clean the payments grain (one row per payment method per order).
-- KEY DECISIONS:
--   - An order can be split across payment methods (e.g., voucher + credit card).
--     This is NOT deduplicated here — aggregation happens in intermediate layer.
--   - accepted_values test on payment_type guards against unexpected new categories.

with source as (

    select * from {{ source('olist_raw', 'order_payments') }}

),

renamed as (

    select
        -- Keys
        order_id,
        payment_sequential,

        -- Payment details
        lower(trim(payment_type))                           as payment_type,
        payment_installments::integer                       as payment_installments,
        payment_value::float                                as payment_amount

    from source

)

select * from renamed
