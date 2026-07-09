-- Quadcopter Sinusoidal Roll, Pitch, and Yaw Control
-- Place this script in the APM/scripts folder

local FREQUENCY_HZ = 50 -- Script update rate (50Hz = every 20ms)
local DELTA_TIME = 1.0 / FREQUENCY_HZ

-- Sinusoid Parameters
local roll_amplitude = 10.0   -- Max roll angle in degrees
local roll_frequency = 0.5   -- Oscillations per second (Hz)

local pitch_amplitude = 8.0  -- Max pitch angle in degrees
local pitch_frequency = 0.3  -- Oscillations per second (Hz)

local yaw_amplitude = 15.0   -- Max yaw offset in degrees
local yaw_frequency = 0.2    -- Oscillations per second (Hz)

local time_elapsed = 0.0

function update()
    -- Only run if the vehicle is armed and in GUIDED mode
    if not arming:is_armed() then
        time_elapsed = 0.0 -- Reset time when disarmed
        return update, 1000 -- Check back in 1 second
    end

    if vehicle:get_mode() ~= 4 then -- 4 is typically GUIDED mode in Copter
        gcs:send_text(0, "Sinusoid Script: Change mode to GUIDED to start")
        return update, 1000 
    end

    -- Increment time
    time_elapsed = time_elapsed + DELTA_TIME

    -- Calculate current target angles using sinusoidal functions
    local target_roll = roll_amplitude * math.sin(2 * math.pi * roll_frequency * time_elapsed)
    local target_pitch = pitch_amplitude * math.sin(4 * math.pi * pitch_frequency * time_elapsed)
    local target_yaw = yaw_amplitude * math.sin(8 * math.pi * yaw_frequency * time_elapsed)

    -- Base climb rate / throttle target to keep it airborne (0-1 scale or hover)
    -- Note: For safety, this script assumes you manage altitude via your RC throttle 
    -- or standard guided altitude holds. 
    
    -- Send target angles (converted to radians) to the vehicle controller
    -- vehicle:set_target_attitude(roll_rad, pitch_rad, yaw_rad, use_yaw_rate, yaw_rate_rad_s)
    vehicle:set_target_attitude(
        math.rad(target_roll), 
        math.rad(target_pitch), 
        math.rad(target_yaw), 
        false, 
        0
    )

    -- Optional: Print telemetry to the Mission Planner Messages tab every ~1 second
    if math.floor(time_elapsed * FREQUENCY_HZ) % FREQUENCY_HZ == 0 then
        gcs:send_text(6, string.format("Targets -> R: %.1f, P: %.1f, Y: %.1f", target_roll, target_pitch, target_yaw))
    end

    return update, (DELTA_TIME * 1000) -- Reschedule next loop
end

gcs:send_text(6, "Sinusoid Attitude Script Loaded Loaded")
return update()