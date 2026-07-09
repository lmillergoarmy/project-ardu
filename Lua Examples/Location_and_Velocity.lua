-- Initialize a persistent target speed variable
local target_speed = 0.0

local function update()
    local current_pos = ahrs:get_position()
    local home_pos = ahrs:get_home()

    if current_pos then
        -- 1. Extract GPS Coordinates
        local lat = current_pos:lat() * 1e-7
        local lon = current_pos:lng() * 1e-7
        
        -- 2. Calculate Relative Altitude
        local relative_alt = 0.0
        if home_pos then
            relative_alt = (current_pos:alt() - home_pos:alt()) * 0.01
        end

        -- 3. Fetch True 3D Velocity Vector
        local velocity_north = 0.0
        local velocity_east  = 0.0
        local velocity_down  = 0.0

        local v_ned_vector = ahrs:get_velocity_NED() 
        if v_ned_vector then
            velocity_north = v_ned_vector:x() or 0.0
            velocity_east  = v_ned_vector:y() or 0.0
            velocity_down  = v_ned_vector:z() or 0.0
        end

        local V_NED = math.sqrt(velocity_north^2 + velocity_east^2)
        local vertical_speed = -velocity_down

        -- 4. NEW: Accelerate forward in the direction the drone is pointed
        -- Increase our target speed by 1 m/s (since this function runs once per second)
        target_speed = target_speed + 1.0

        -- Get current heading (yaw) in radians
        local current_yaw = ahrs:get_yaw()

        if current_yaw then
            -- Breakdown the target forward speed into North and East vector components
            local target_vel_north = target_speed * math.cos(current_yaw)
            local target_vel_east  = target_speed * math.sin(current_yaw)
            local target_vel_down  = 0.0 -- Maintain current altitude

            -- Create a Vector3f object to hold the target velocity
            local target_vector = Vector3f()
            target_vector:x(target_vel_north)
            target_vector:y(target_vel_east)
            target_vector:z(target_vel_down)

            -- Send the velocity target command to the vehicle
            -- Note: This only takes effect if the vehicle is in GUIDED mode!
            vehicle:set_target_velocity_NED(target_vector)
        end

        -- 5. Print telemetry updates
        gcs:send_text(6, string.format("POS -> Lat: %.7f | Lon: %.7f | Alt: %.1fm | Speed: %.2f m/s | Target: %.1fm/s", lat, lon, relative_alt, V_NED, target_speed))
    else
        gcs:send_text(3, "Waiting for EKF position fix...")
    end

    return update, 1000 -- Repeat every 1000ms (1 second)
end

return update()