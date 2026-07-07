-- Periodic function to fetch position data
function update()

    -- 1. Grab the current position location object from AHRS
    local current_pos = ahrs:get_position()

    -- 2. Verify that the EKF has a valid position lock
    if current_pos then

        -- 3. Extract individual parameters 
        local latitude  = current_pos:lat() * 1.0e-7  -- Convert back to standard degrees
        local longitude = current_pos:lng() * 1.0e-7  -- Convert back to standard degrees
        local altitude  = current_pos:alt() * 0.01    -- Convert centimeters to meters

        -- 4. Stream coordinates straight to Mission Planner messages tab
        gcs:send_text(6, string.format("GPS: Lat=%.7f, Lon=%.7f, Alt=%.2fm", latitude, longitude, altitude))
    else
        gcs:send_text(3, "Waiting for GPS/EKF position fix...")
    end

    -- Repeat every 1000 milliseconds (1 second)
    return update, 1000 
end

-- Initialize the loop
return update()