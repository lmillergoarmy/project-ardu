-- ArduCopter/Rover Lua script for Sinusoidal Movement (Fixed Nil Errors)
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
local center_lat = nil
local center_lng = nil
local center_alt = nil
local start_time = nil

function update()
  -- 1. Pre-flight Safety Checks
  if vehicle:get_mode() ~= guided_mode then
    gcs:send_text(6, "Lua: Switching to GUIDED mode...")
    vehicle:set_mode(guided_mode)
    return update, 1000 
  end

  -- 2. Capture current position safely using the AHRS system
  if not center_lat then
    local current_pos = ahrs:get_location() -- Bulletproof method for current global position
    
    -- If AHRS doesn't have a valid GPS/Pos lock yet, it returns nil
    if not current_pos then
      gcs:send_text(3, "Lua: Waiting for AHRS position lock...")
      return update, 1000
    end

    -- Extract coordinates safely (returns integers * 1e7)
    center_lat = current_pos:lat() / 1e7
    center_lng = current_pos:lng() / 1e7
    
    -- Safely fetch relative altitude
    -- ahrs:get_relative_position_NED() returns a Vector3f object or nil
    local position_ned = ahrs:get_relative_position_NED()
    if position_ned then
      -- NED coordinates mean Z is negative downwards, so flip it to get altitude upwards
      center_alt = -position_ned:z()
    else
      center_alt = 0.0 -- Fallback if relative tracking isn't live yet
    end
    
    start_time = millis():tofloat() / 1000.0
    gcs:send_text(6, string.format("Lua: Anchored! Lat: %.6f, Lng: %.6f, Alt: %.1fm", center_lat, center_lng, center_alt))
  end

  -- 3. Calculate elapsed time
  local current_time = (millis():tofloat() / 1000.0) - start_time

  -- 4. Calculate sinusoidal offsets
  local current_lat = center_lat + lat_amplitude * math.sin(2 * math.pi * current_time / lat_period)
  local current_lng = center_lng + lng_amplitude * math.sin(4 * math.pi * current_time / lng_period)
  local current_alt = center_alt + alt_amplitude * math.sin(8 * math.pi * current_time / alt_period)

  -- 5. Convert and apply to the Location object
  target_loc:lat(math.floor(current_lat * 1e7))
  target_loc:lng(math.floor(current_lng * 1e7))
  target_loc:alt(math.floor(current_alt * 100))
  target_loc:relative_alt(true)

  -- 6. Command the vehicle to the destination
  vehicle:set_wp_destination(target_loc)

  return update, 1000 
end

return update()
