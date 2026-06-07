-- stg_olist__products.sql
-- PURPOSE: Clean the product catalog and join in English category names.
-- KEY DECISIONS:
--   - Join to translation table here (staging) so every downstream model
--     gets English categories for free without re-joining.
--   - Compute volumetric_weight_g (logistics standard: L*W*H / 5000 * 1000)
--     as a useful derived feature for shipping cost analysis.

with source as (

    select * from {{ source('olist_raw', 'products') }}

),

translations as (

    select * from {{ source('olist_raw', 'product_category_name_translation') }}

),

renamed as (

    select
        -- Key
        p.product_id,

        -- Category (Portuguese + English)
        p.product_category_name                                     as category_name_pt,
        coalesce(t.product_category_name_english, 'unknown')        as category_name_en,

        -- Product dimensions (raw CSV has typo: 'lenght' not 'length' — aliased here)
        p.product_name_lenght::integer                              as name_length,
        p.product_description_lenght::integer                       as description_length,
        p.product_photos_qty::integer                               as photos_count,

        -- Physical attributes
        p.product_weight_g::float                                   as weight_g,
        p.product_length_cm::float                                  as length_cm,
        p.product_height_cm::float                                  as height_cm,
        p.product_width_cm::float                                   as width_cm,

        -- Derived: volumetric weight in grams (standard logistics formula)
        round(
            (p.product_length_cm::float * p.product_width_cm::float * p.product_height_cm::float)
            / 5000.0 * 1000,
            2
        )                                                           as volumetric_weight_g

    from source p
    left join translations t
        on p.product_category_name = t.product_category_name

)

select * from renamed
