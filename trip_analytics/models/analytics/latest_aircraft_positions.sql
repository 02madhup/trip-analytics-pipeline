-- One row per aircraft: its most recent known position from any poll.
-- This is the table a live dashboard would query.

with ranked as (

    select
        *,
        row_number() over (
            partition by icao24
            order by polled_at desc
        ) as rn
    from {{ ref('stg_flight_positions') }}
    where on_ground = false
      and latitude is not null
      and longitude is not null

)

select
    icao24,
    callsign,
    origin_country,
    latitude,
    longitude,
    baro_altitude,
    velocity,
    true_track,
    vertical_rate,
    polled_at as last_seen_at
from ranked
where rn = 1