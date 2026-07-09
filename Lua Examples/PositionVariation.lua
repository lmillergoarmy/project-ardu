-- ArduCopter/Rover Lua script for Sinusoidal Movement (Guaranteed Position Init)
-- --- CONFIGURATION ---
local lat_amplitude = 0.0001    -- How far North/South it moves (~11 meters)
local lng_amplitude = 0.0001    -- How far East/West it moves (~9 meters)
local alt_amplitude = 5         -- How far up/down it moves (meters)

local lat_period = 30           -- Time in seconds to complete one Lat cycle
local lng_period = 45           -- Time in seconds to complete one Lng cycle
local alt_period = 20           -- Time in seconds to complete one Alt cycle

local guided_mode = 4           -- GUIDED mode for Copter
-- ---------------------

local target_loc = Location()
local center_lat, center_lng, center_alt, start_time

-- Forward declare the functions so they can reference each other cleanly
local init_position
local update_trajectory

-- 1. INITIALIZATION FUNCTION: Runs repeatedly until GPS lock is solid
function init_position()
  local current_pos = ahrs:get_location()
  local position_ned = ahrs:get_relative_position_NED()

  -- Ensure BOTH the global location and local position vectors are populated
  if not current_pos or not position_ned then
    gcs:send_text(4, "Lua Init: Waiting for absolute & relative position lock...")
    return init_position, 2000 -- Retry in 2 seconds
  end

  -- Cache values into variables immediately (never nil past this point)
  center_lat = current_pos:lat() / 1e7
  center_lng = current_pos:lng() / 1e7
  center_alt = -position_ned:z()
  start_time = millis():tofloat() / 1000.0

  gcs:send_text(6, string.format("Lua: Anchored! Lat: %.6f, Lng: %.6f, Alt: %.1fm", center_lat, center_lng, center_alt))
  
  -- Hand over execution cleanly to the main flight trajectory loop
  return update_trajectory, 1000
end

-- 2. MAIN RUNTIME FUNCTION: Only executes once position variables are guaranteed integers/floats
function update_trajectory()
  -- Pre-flight Safety Checks
  if not vehicle:get_armed() then
    gcs:send_text(6, "Lua: Waiting for arm...")
    return update_trajectory, 2000
  end

  if vehicle:get_mode() ~= guided_mode then
    gcs:send_text(6, "Lua: Switching to GUIDED mode...")
    vehicle:set_mode(guided_mode)
    return update_trajectory, 1000 
  end

  -- Calculate elapsed time
  local current_time = (millis():tofloat() / 1000.0) - start_time

  -- Calculate sinusoidal offsets (variables are 100% guaranteed to be non-null here)
  local current_lat = center_lat + lat_amplitude * math.sin(2 * math.pi * current_time / lat_period)
  local current_lng = center_lng + lng_amplitude * math.sin(4 * math.pi * current_time / lng_period)
  local current_alt = center_alt + alt_amplitude * math.sin(8 * math.pi * current_time / alt_period)

  -- Convert and apply to the Location object
  target_loc:lat(math.floor(current_lat * 1e7))
  target_loc:lng(math.floor(current_lng * 1e7))
  target_loc:alt(math.floor(current_alt * 100))
  target_loc:relative_alt(true)

  -- Command the vehicle to the destination
  vehicle:set_wp_destination(target_loc)

  return update_trajectory, 1000 
end

-- Kick off the script strictly using the initialization routine first
return init_position()
