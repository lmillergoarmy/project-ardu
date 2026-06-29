-- ArduPilot Lua: Force all 4 quad motors to same PWM sequentially on Arming
local MOTOR_CHANNELS = {9, 10, 11, 12} -- Internal 0-indexed channels (SERVO9, 10, 11, 12)

-- Desired motor PWM
local TIMEOUT_MS = 500
local UPDATE_RATE_MS = 13 -- Run every 100ms

-- Initialize counters and state tracking
--local cycles = 0
local test_started = false

local PWM_BASE = 1300 --Base PWM that is the is the vertical offset of the sinuoid



local pwm = tonumber(0)  -- Table to store preloaded CSV data
local still_reading = true --sets still_reading to true to track if the table is still being read off 

local file = io.open('/APM/scripts/multisine_PWM_Test_1_deg_3_0_Hz_10_bins_4_s.csv', 'r') -- attempts to open csv
  if not file then
    gcs:send_text(6, "Error: Unable to open CSV file.")
    return
  else
    gcs:send_text(6, "Opened CSV Sucessfully")
    file:read() -- Skips header
  end

function update()
    -- Check if the vehicle is armed
    if not arming:is_armed() then
        -- If it disarms during the test, reset everything
        if test_started then
            gcs:send_text(4, "Vehicle disarmed. Resetting motor script.")
            --cycles = 0
            test_started = false
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
    --local seconds_elapsed = (cycles * UPDATE_RATE_MS) / 1000
    --dummy function that is a holdover from previous functions, kept in case it is needed

    local line = file:read()

    if line then
      local index_str, pwm_str = line:match("([^,]+),([^,]+)") --Isolates the two lines in the CSV file on the line being read
      local index = tonumber(index_str:match("^%s*(.-)%s*$"))  -- Trim and convert to number
      pwm = math.floor(0.5 + tonumber(pwm_str:match("^%s*(.-)%s*$")))    -- Trim and convert to number

      --if index and pwm then
      gcs:send_text(6, pwm) -- Used for data collection and bug testing
    else
      -- Close the file when done
      file:close()
      file = nil
      still_reading = false --Sets the variable that checks if the file is reading to false
      gcs:send_text(6, "File Closed")
      
    end

    local target_pwm = PWM_BASE + pwm --Gives the pwm the motors will target from the pwm increment read off the CSV file and the base PWM (try to draw this off the drone for a flight test)

    if still_reading then  for i = 1, #MOTOR_CHANNELS do --Checks for if 
            SRV_Channels:set_output_pwm_chan_timeout(
                MOTOR_CHANNELS[i],
                target_pwm,
                TIMEOUT_MS
            )
        end 

    else
        gcs:send_text(6, "Motor test complete. Exiting script.")
        arming:disarm() -- Force disarm to stop motors immediately
        return 
    end

    --cycles = cycles + 1 --Variable to hold the number of times the loop has iterated, commented out to save on computation power

    -- Re-schedule this exact function to run again in 100ms
    return update, UPDATE_RATE_MS
end

-- Send a boot message to the GCS (Mission Planner/QGC)
gcs:send_text(6, "Motor override script loaded. Waiting for ARM...")

-- Start the loop
return update, UPDATE_RATE_MS
