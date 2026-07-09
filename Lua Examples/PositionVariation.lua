-- ArduCopter/Rover Lua script for Sinusoidal Movement (Guaranteed Position Init)
-- --- CONFIGURATION ---
local lat_amplitude = 0.0001    -- How far North/South it moves (~11 meters)
local lng_amplitude = 0.0001    -- How far East/West it moves (~9 meters)
local alt_amplitude = 2         -- Reduced slightly to prevent "Thrust Loss" motor saturation
local alt_offset_base = 5       -- Added a base altitude so it stays safely in the air

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
  -- Correct API method name is get_relative_position_NED_home()
  local position_ned = ahrs:get_relative_position_NED_home()

  -- ArduPilot returns 'false' (boolean) if NED position isn't ready yet
  if not current_pos or (position_ned == false) then
    gcs:send_text(4, "Lua Init: Waiting for absolute & relative position lock...")
    return init_position, 2000 -- Retry in 2 seconds
  end

  -- Cache values into variables immediately (never nil past this point)
  center_lat = current_pos:lat() / 1e7
  center_lng = current_pos:lng() / 1e7
  -- Z is downward in NED coordinates, so flipping the sign gives us a positive height
  center_alt = -position_ned:z()
  start_time = millis():tofloat() / 1000.0

  gcs:send_text(6, string.format("Lua: Anchored! Lat: %.6f, Lng: %.6f, Alt: %.1fm", center_lat, center_lng, center_alt))
  
  -- Hand over execution cleanly to the main flight trajectory loop
  return update_trajectory, 1000
end

-- 2. MAIN RUNTIME FUNCTION: Only executes once position variables are guaranteed integers/floats
function update_trajectory()
  -- Pre-flight Safety Checks
  if not arming:is_armed() then
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

  -- Calculate sinusoidal offsets
  local current_lat = center_lat + lat_amplitude * math.sin(2 * math.pi * current_time / lat_period)
  local current_lng = center_lng + lng_amplitude * math.sin(4 * math.pi * current_time / lng_period)
  
  -- Modified Alt logic: swings up and down around (center altitude + a base offset) 
  -- so it doesn't accidentally dive straight back down into the ground.
  local current_alt = center_alt + alt_offset_base + alt_amplitude * math.sin(2 * math.pi * current_time / alt_period)

  -- Convert and apply to the Location object
  target_loc:lat(math.floor(current_lat * 1e7))
  target_loc:lng(math.floor(current_lng * 1e7))
  target_loc:alt(math.floor(current_alt * 100))
  target_loc:relative_alt(true)

  -- FIX: Changed 'vehicle:set_wp_destination(target_loc)' to 'vehicle:set_target_location(target_loc)'
  vehicle:set_target_location(target_loc)

  return update_trajectory, 1000 
end

-- Kick off the script strictly using the initialization routine first
return init_position()
