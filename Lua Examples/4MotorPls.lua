-- ArduPilot Lua: Force all 4 quad motors to same PWM

local MOTOR_CHANNELS = {9, 10, 11, 12}

-- Desired motor PWM
-- 1000 = off
-- 1500 = ~50% throttle
-- 1250 = ~25% throttle
-- 1100 = ~10% throttle
local PWM_VALUE = 1100

local TIMEOUT_MS = 500
local UPDATE_RATE_MS = 100

function update()

    for i = 1, #MOTOR_CHANNELS do
        SRV_Channels:set_output_pwm_chan_timeout(
            MOTOR_CHANNELS[i],
            PWM_VALUE,
            TIMEOUT_MS
        )
    end

    return update, UPDATE_RATE_MS
end

return update()
