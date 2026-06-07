-- stg_olist__order_reviews.sql
-- PURPOSE: Clean the reviews grain.
-- KEY DECISIONS:
--   - review_id is NOT unique in the raw data (Olist data quirk — some re-submissions).
--     We keep all rows; uniqueness is enforced at the order level in downstream models.
--   - response_time_hours = how quickly Olist responded to the review.

with source as (

    select * from {{ source('olist_raw', 'order_reviews') }}

),

renamed as (

    select
        -- Keys
        review_id,
        order_id,

        -- Rating
        review_score::integer                                       as review_score,

        -- Text (nullable — most reviews have no text)
        nullif(trim(review_comment_title), '')                      as review_title,
        nullif(trim(review_comment_message), '')                    as review_message,

        -- Timestamps
        try_to_timestamp(review_creation_date)                      as review_created_at,
        try_to_timestamp(review_answer_timestamp)                   as review_answered_at,

        -- Derived: hours between review creation and Olist response
        datediff(
            'hour',
            try_to_timestamp(review_creation_date),
            try_to_timestamp(review_answer_timestamp)
        )                                                           as response_time_hours

    from source

)

select * from renamed
