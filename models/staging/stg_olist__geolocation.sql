-- stg_olist__geolocation.sql
-- PURPOSE: Deduplicate and clean geolocation data.
-- KEY DECISIONS:
--   - Raw table has MANY rows per zip code prefix (multiple lat/lng readings).
--   - We take the average lat/lng per zip code — a centroid approximation.
--     This gives us one row per zip prefix, suitable for joining to customers/sellers.

with source as (

    select * from {{ source('olist_raw', 'geolocation') }}

),

deduped as (

    select
        geolocation_zip_code_prefix                         as zip_code_prefix,
        round(avg(geolocation_lat::float), 6)               as latitude,
        round(avg(geolocation_lng::float), 6)               as longitude,
        -- Take the most common city/state for this zip prefix
        mode(lower(trim(geolocation_city)))                 as city,
        mode(upper(trim(geolocation_state)))                as state

    from source
    group by 1

)

select * from deduped
