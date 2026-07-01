-- ArduPilot Lua: Force all 4 quad motors to same PWM sequentially on Arming
local MOTOR_CHANNELS = {9, 10, 11, 12} -- Internal 0-indexed channels (SERVO9, 10, 11, 12)

-- Desired motor PWM
local PWM_BASE = 1100
local PWM_RAMP = 1250
local PWM_END  = 1500

local TIMEOUT_MS = 500
local UPDATE_RATE_MS = 100 -- Run every 100ms

-- Initialize counters and state tracking
local cycles = 0
local test_started = false
local current_phase = 0 -- Tracks the active phase (0: idle, 1: base, 2: ramp, 3: end)

function update()
    -- Check if the vehicle is armed
    if not arming:is_armed() then
        -- If it disarms during the test, reset everything
        if test_started then
            gcs:send_text(4, "Vehicle disarmed. Resetting motor script.")
            cycles = 0
            test_started = false
            current_phase = 0
        end
        -- Keep looping and checking for arming state without incrementing cycles
        return update, UPDATE_RATE_MS
    end

    -- If we reach here, the vehicle is armed
    if not test_started then
        gcs:send_text(6, "Vehicle Armed! Starting motor sequence.")
        test_started = true
    end

    -- Convert cycles to total seconds elapsed
    local seconds_elapsed = (cycles * UPDATE_RATE_MS) / 1000
    local target_pwm = 1000 -- Default to off if outside bounds

    -- Determine target PWM based on elapsed time and trigger single phase notifications
    if seconds_elapsed <= 5 then
        target_pwm = PWM_BASE
        if current_phase ~= 1 then
            gcs:send_text(6, "Phase 1: 1100 PWM") 
            current_phase = 1
        end
    elseif seconds_elapsed <= 10 then
        target_pwm = PWM_RAMP
        if current_phase ~= 2 then
            gcs:send_text(6, "Phase 2: 1250 PWM")
            current_phase = 2
        end
    elseif seconds_elapsed <= 15 then
        target_pwm = PWM_END
        if current_phase ~= 3 then
            gcs:send_text(6, "Phase 3: 1500 PWM")
            current_phase = 3
        end
    else
        -- Past 15 seconds, stop overriding and exit the script loop
        gcs:send_text(6, "Motor test complete. Exiting script.")
        arming:disarm() -- Force disarm to stop motors immediately
        return 
    end

    -- Send the PWM command to all listed channels
    for i = 1, #MOTOR_CHANNELS do
        SRV_Channels:set_output_pwm_chan_timeout(
            MOTOR_CHANNELS[i],
            target_pwm,
            TIMEOUT_MS
        )
    end

    -- Increment our cycle counter only while armed and running
    cycles = cycles + 1

    -- Re-schedule this exact function to run again in 100ms
    return update, UPDATE_RATE_MS
end

-- Send a boot message to the GCS (Mission Planner/QGC)
gcs:send_text(6, "Motor override script loaded. Waiting for ARM...")

-- Start the loop
return update, UPDATE_RATE_MS
