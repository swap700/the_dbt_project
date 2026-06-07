-- stg_olist__sellers.sql
-- PURPOSE: Clean the seller/merchant catalog.

with source as (

    select * from {{ source('olist_raw', 'sellers') }}

),

renamed as (

    select
        -- Key
        seller_id,

        -- Location
        seller_zip_code_prefix              as zip_code_prefix,
        lower(trim(seller_city))            as seller_city,
        upper(trim(seller_state))           as seller_state

    from source

)

select * from renamed
