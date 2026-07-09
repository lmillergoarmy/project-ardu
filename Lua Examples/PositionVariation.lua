-- ArduCopter/Rover Lua script for Sinusoidal Movement
local center_lat = 38.8300000   -- Center Latitude of oscillation
local center_lng = -77.3000000  -- Center Longitude of oscillation
local center_alt = 20           -- Center Altitude in meters

-- --- CONFIGURATION ---
local lat_amplitude = 0.0001    -- How far North/South it moves (~11 meters)
local lng_amplitude = 0.0001    -- How far East/West it moves (~9 meters)
local alt_amplitude = 5         -- How far up/down it moves (meters)

local lat_period = 30           -- Time in seconds to complete one Lat cycle
local lng_period = 45           -- Time in seconds to complete one Lng cycle (different to create a 2D pattern)
local alt_period = 20           -- Time in seconds to complete one Alt cycle

local guided_mode = 4           -- GUIDED mode for Copter
-- ---------------------

local target_loc = Location()
local start_time = millis():tofloat() / 1000.0 -- Get starting time in seconds

function update()
  -- 1. Pre-flight Safety Checks
  if not vehicle:get_armed() then
    gcs:send_text(6, "Lua: Waiting for arm...")
    return update, 2000
  end

  if vehicle:get_mode() ~= guided_mode then
    gcs:send_text(6, "Lua: Switching to GUIDED mode...")
    vehicle:set_mode(guided_mode)
    return update, 1000 
  end

  -- 2. Calculate elapsed time
  local current_time = (millis():tofloat() / 1000.0) - start_time

  -- 3. Calculate sinusoidal offsets
  -- Formula: center + amplitude * sin(2 * pi * time / period)
  local current_lat = center_lat + lat_amplitude * math.sin(2 * math.pi * current_time / lat_period)
  local current_lng = center_lng + lng_amplitude * math.sin(2 * math.pi * current_time / lng_period)
  local current_alt = center_alt + alt_amplitude * math.sin(2 * math.pi * current_time / alt_period)

  -- 4. Convert and apply to the Location object
  target_loc:lat(math.floor(current_lat * 1e7))
  target_loc:lng(math.floor(current_lng * 1e7))
  target_loc:alt(math.floor(current_alt * 100))
  target_loc:relative_alt(true)

  -- 5. Command the vehicle to the dynamically updated location
  -- Because the target changes every second, we continuously update the destination
  vehicle:set_wp_destination(target_loc)

  return update, 1000 -- Update target every 1 second
end

return update()