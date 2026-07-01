-- ArduPilot Lua: Force all 4 quad motors to same PWM sequentially on Arming
local MOTOR_CHANNELS = {9, 10, 11, 12} -- Internal 0-indexed channels (SERVO9, 10, 11, 12)

-- Desired motor PWM
local PWM_BASE = 1200
local TIMEOUT_MS = 500
local UPDATE_RATE_MS = 100 -- Run every 100ms

-- Initialize counters and state tracking
local cycles = 0
local test_started = false

function update()
    -- Check if the vehicle is armed
    if not arming:is_armed() then
        -- If it disarms during the test, reset everything
        if test_started then
            gcs:send_text(4, "Vehicle disarmed. Resetting motor script.")
            cycles = 0
            test_started = false
        end
        -- Keep looping and checking for arming state without incrementing cycles
        return update, UPDATE_RATE_MS
    end

    -- If we reach here, the vehicle is armed
    if not test_started then
        gcs:send_text(6, "Vehicle Armed! Starting sine-wave motor sequence.")
        test_started = true
    end

    -- Convert cycles to total seconds elapsed
    local seconds_elapsed = (cycles * UPDATE_RATE_MS) / 1000
    local target_pwm = 1000 -- Default to off if outside bounds

    if seconds_elapsed <= 12 then
        -- Calculates a smooth sine wave cycle across the 12-second window (oscillating between 1100 and 1300 PWM)
        target_pwm = PWM_BASE + math.floor(100 * math.sin(seconds_elapsed * 2 * math.pi / 12))
        
        for i = 1, #MOTOR_CHANNELS do
            SRV_Channels:set_output_pwm_chan_timeout(
                MOTOR_CHANNELS[i],
                target_pwm,
                TIMEOUT_MS
            )
        end
    else
        -- Past 12 seconds, stop overriding and exit the script loop
        gcs:send_text(6, "Motor test complete. Exiting script.")
        arming:disarm() -- Force disarm to stop motors immediately
        return 
    end

    -- CRITICAL FIX: Increment our cycle counter only while armed and running
    cycles = cycles + 1

    -- Re-schedule this exact function to run again in 100ms
    return update, UPDATE_RATE_MS
end

-- Send a boot message to the GCS (Mission Planner/QGC)
gcs:send_text(6, "Motor override script loaded. Waiting for ARM...")

-- Start the loop
return update, UPDATE_RATE_MS
