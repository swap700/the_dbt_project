-- stg_olist__customers.sql
-- PURPOSE: Clean and rename the raw customers table.
-- KEY DECISIONS:
--   - customer_id is ORDER-level (Olist quirk). customer_unique_id is the true person.
--   - We expose both but rename clearly to avoid downstream confusion.

with source as (

    select * from {{ source('olist_raw', 'customers') }}

),

renamed as (

    select
        -- Primary key (order-scoped)
        customer_id,

        -- True person identifier — use this for CLV calculations
        customer_unique_id,

        -- Location
        customer_zip_code_prefix                        as zip_code_prefix,
        lower(trim(customer_city))                      as customer_city,
        upper(trim(customer_state))                     as customer_state

    from source

)

select * from renamed
