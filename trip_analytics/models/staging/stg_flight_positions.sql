select
    icao24,
    callsign,
    origin_country,
    to_timestamp_ntz(time_position) as time_position,
    to_timestamp_ntz(last_contact) as last_contact,
    longitude,
    latitude,
    baro_altitude,
    on_ground,
    velocity,
    true_track,
    vertical_rate,
    geo_altitude,
    polled_at
from {{ source('raw', 'raw_bangalore_flights') }}
where icao24 is not null