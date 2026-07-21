--Notes for script usage:

--All time is kept in MS, so format any file to be read accordingly

--Note: Any comments in all caps are intended for developer use and will not be present in final script

--NOTES FOR SCRIPT WRITING
--NEED TO SAVE FIXED VELOCITY, POSITION, ECT TO RUN AS BASELINE VALUES FOR THE MULTISINE


--Boolean values controlled by the code
local csv_fully_loaded = false --Allows the code to detect when the csv is finished loading
local test_started = false --Monitors if the code has been started 

--Temporary Boolean Values, intended to be controlled by an external device
local pos_Flag = true --Flags if a Position test is being conducted
local att_Flag = false --Flags if a Attitude test if being conducted 
local vel_Flag = false --Flags if a velocity test is being conducted

--Dummy variables designed to store data generated in the code
local csv_data = {} --Dummy table to hold the data obtained from the CSV file
local current_index = 1
local initial_time = 0

--Position Test Variables
local target_pos = Location()
local trimmed_lat, trimmed_lng, trimmed_alt

--Velocity test variables
local velocity_north_trimmed = 0.0
local velocity_east_trimmed  = 0.0
local velocity_down_trimmed = 0.0

--Inputs
local line_block = 20 --Designates the maximum size of the table
local file_name = "PosVel_Test" --input the file name, you do not need to include path or file type
--Note: The final version of the code will use one generic set of data with an amplitude of 1 unit

local update_rate_ms = 0 --Determined the update rate of the Update() function
--Note: How this works is that it runs the code then waits the time required, Note for future usage: If this is used to keep track of time it will create steady state error in your timekeeping

--Uneeded inputs (REMOVE THIS MARKER ONCE FINISHED WITH CODE AND MAKE SURE TO ADD UNITS FOR FINAL CODE)
local latlng_amp = 0.0001 -- Amplitude of the Position multisine for latitude and longitude
local alt_amp = 2 --Amplitude of Altititude Multsine 

local vel_amp = 1 -- Amplitude of the Velocity multisine
local att_amp = 1 -- Amplitude of the Attitude multisine

--Test inputs: Inputs for use on the static testbed for code validation
local test_Flag = false --Flags if a test using pwm is being conducted, used for bug testing before simulink model is active
local test_amp = 1 --Amplitude of test PWM
local baseline_pwm = 1400 --Represents a velocity/ position hold to vary from

--Setup
file_name = "/APM/scripts/" .. file_name .. ".csv" -- Formats the code so that it can be found by the io.open function

function open_file(file_name) --This function is used to open a file and write
  File = io.open(file_name, "r")
    if not File then
      gcs:send_text(6, "Error: Unable to open CSV file.")
    return
    end
  File:read() --Skips the header
end


function preload_file(file)
local t0 = 0 --Dummy variable to hold initial for line block
local X0 = 0 --Dummy variable to hold initial X value for line block
local Y0 = 0 --Dummy variable to hold initial Y value for line block
local Z0 = 0 --Dummy variable to hold initial Z value for line block
 
  if csv_data[#csv_data] then --Stores the last values of the 
    t0 = csv_data[#csv_data].time
    X0 = csv_data[#csv_data].X
    Y0 = csv_data[#csv_data].Y
    Z0 = csv_data[#csv_data].Z
  end

  current_index = 1 --Resets the index so that that find_nearest_data knows to start from the bottom of the table
  csv_data = {} -- Resets the table so that the old lines are overwriten as not to bloat size

  if t0 then
    table.insert(csv_data, {time = t0, X = X0, Y = Y0, Z = Z0}) --Last values of the previous table are the first values of the new table
  end



  -- Read a chunk of lines (e.g., 20 lines at a time) in each cycle
  for i = 1, line_block do
    local line = file:read()
    if line then
      local time_str, X_str, Y_str, Z_str = line:match("([^,]+),([^,]+),([^,]+),([^,]+)")
      local time = tonumber(time_str:match("^%s*(.-)%s*$"))  -- Trim and convert to number
      local X = tonumber(X_str:match("^%s*(.-)%s*$"))    -- Trim and convert to number
      local Y = tonumber(Y_str:match("^%s*(.-)%s*$"))    -- Trim and convert to number
      local Z = tonumber(Z_str:match("^%s*(.-)%s*$"))    -- Trim and convert to number
        if time then
          table.insert(csv_data, {time = time, X = X, Y = Y, Z = Z})
        end
    else
      -- Close the file when done
      file:close()
      --file = nil --Think this line is uneeded, but saving in case it is needed
      csv_fully_loaded = true  -- Mark the CSV as fully loaded
      gcs:send_text(6, "File fully loaded into memory.")
      break
    end
  end
end

function find_nearest_data(elapsed_time)
  -- Iterate through the preloaded csv_data to find the appropriate time range
  for i = current_index, #csv_data - 1 do
    if csv_data[i].time <= elapsed_time and csv_data[i + 1].time > elapsed_time then
      current_index = i  -- Update current_index to start from this point next time
      return csv_data[i], csv_data[i + 1]  -- Return the two nearest points
    end
  end
end

-- Linear interpolation function
function interpolate(x1, y1, x2, y2, x)
  return y1 + (y2 - y1) * (x - x1) / (x2 - x1)
end

function update()
  if not arming:is_armed() then 
    if test_started then --Detects if the test was stopped prematurely
      gcs:send_text(4, "Vehicle was disarmed prematurely")
      test_started = false
    end
    return update, update_rate_ms --Stops the script from going further if the drone is not armed
  end  

  if not test_started then --If the vehicle is armed this will enable the script to run
      gcs:send_text(6, "Test Initialized, select test when ready")
      test_started = true
  end

  local elapsed_time = millis():tofloat() - initial_time --Finds the elapsed time since the file was opened

  --This code uses if statements to determine when the test is started and which one it is
  --NOTE: POTENTIAL ERROR IN USEAGE, IF TEST SWITCHED PREMATURELY THEN IT MIGHT NOT START AT THE CORRECT LOCATION IN CSV, either fix in code or guard against in usage (Perhaps don't allow test to be changed until test is complete, with provisions given for imediate terimination of script if something goes wrong)
  if pos_Flag then
    if not File then --Checks if the file is opened and if it isn't it attempts to open it
      csv_fully_loaded = false --Sets the file to not fully loaded before
      open_file(file_name)
      gcs:send_text(6, "Started Position Test")

      local current_pos = ahrs:get_location() --Get the current location in latitude and longitude
      local position_ned = ahrs:get_relative_position_NED_home() --Used to find the altitude for usage
      
      trimmed_lat = current_pos:lat() / 1e7 --Save the latitude
      trimmed_lng = current_pos:lng() / 1e7 --Save the longitude
      trimmed_alt = position_ned:z() / 1e7 --Save the base altitude

      preload_file(File) --Preloads the first block of data associated with the file

      --Find current time to be used as a reference
      initial_time = millis():tofloat() -- Sets the initial time of the test in ms       

    elseif elapsed_time >= csv_data[#csv_data].time and not csv_fully_loaded then -- Controls when the next block of the csv file is read, time is assumed to be kept in ms 
      preload_file(File)
    elseif elapsed_time < csv_data[#csv_data].time then --If the code has reached this point then then it is ready to find the value to be written
      local pos1, pos2 = find_nearest_data(elapsed_time) --find the two times closest to the current time
      local delta_position_latitude = latlng_amp*interpolate(pos1.time, pos1.X, pos2.time, pos2.X, elapsed_time) -- find the change in latitude from the trimmed condition
      local delta_position_longitude = latlng_amp*interpolate(pos1.time, pos1.Y, pos2.time, pos2.Y, elapsed_time) -- find the change in longitude from the trimmed condition
      local delta_position_altitude = alt_amp*interpolate(pos1.time, pos1.Z, pos2.time, pos2.Z, elapsed_time) -- find the change in altitude from the trimmed condition

      --Update the target_position variable so the drone knows where to go 
      target_pos:lat(math.floor((trimmed_lat + delta_position_latitude) * 1e7))
      target_pos:lng(math.floor((trimmed_lng + delta_position_longitude) * 1e7))
      target_pos:alt(math.floor((trimmed_alt + delta_position_altitude) * 100)) --MIGHT NEED TO CHANGE CONSTANT MULIPLE 
      target_pos:relative_alt(true)

      gcs:send_text(6, "Lat: " .. tostring(delta_position_latitude*1e7) .. " Lng: " .. tostring(delta_position_longitude*1e7) .. " Alt: " .. tostring(delta_position_altitude*100))
      
      --Send new position to the drone
      vehicle:set_target_location(target_pos)

    else --If the code has reached this point csv_fully_loaded has been marked, sets variable to false to stop testing algorithim
      gcs:send_text(6, "Position test has finished, ready for next test.")
      File = nil
      pos_Flag = false
    end

  elseif att_Flag then
    if not File then --Checks if the file is opened and if it isn't it attempts to open it
      csv_fully_loaded = false --Sets the file to not fully loaded before
      open_file(file_name)
      --WILL NEED TO GET CURRENT ROLL, PITCH, AND YAW TO SET AS BASELINE
      preload_file(File) --Preloads the first block of data associated with the file

      --Find current time to be used as a reference
      initial_time = millis():tofloat() -- Sets the initial time of the test in ms 

    elseif elapsed_time >= csv_data[#csv_data].time and not csv_fully_loaded then -- Controls when the next block of the csv file is read, time is assumed to be kept in ms 
      preload_file(File)
    elseif elapsed_time < csv_data[#csv_data].time then --If the code has reached this point then then it is ready to find the value to be written
      --Find Attitude at given time from csv 

      local att1, att2 = find_nearest_data(elapsed_time)
      local delta_roll = att_amp*interpolate(att1.time, att1.X, att2.time, att2.X, elapsed_time) -- find the change in roll from the trimmed condition 
      local delta_pitch = att_amp*interpolate(att1.time, att1.Y, att2.time, att2.Y, elapsed_time) -- find the change in pitch from the trimmed condition  
      local delta_yaw = att_amp*interpolate(att1.time, att1.Z, att2.time, att2.Z, elapsed_time) -- find the change in yaw from the trimmed condition  
    
      --IF USING TRIMMED CONDITION SUM THAT WITH THE DELTA TERMS TO GET ACTUAL INPUT

      --Send inputs to the vehicle
      vehicle:set_target_angle_and_climbrate(delta_roll, delta_pitch, delta_yaw, 0, false, 0)
    
    else --If the code has reached this point csv_fully_loaded has been marked, sets variable to false to stop testing algorithim
      gcs:send_text(6, "Attitude test has finished, ready for next test.")
      File = nil
      att_Flag = false
    end

  elseif vel_Flag then
    if not File then --Checks if the file is opened and if it isn't it attempts to open it as well as set up the rest of the test
      csv_fully_loaded = false --Sets the file to not fully loaded before
      open_file(file_name) --Attempts to open file

      --Find current trimmed velocity, in earth fixed reference frame, at start of test to use as offset for multisine or chirp and save them to be used later
      local velocity_trimmed = ahrs:get_velocity_NED()
      velocity_north_trimmed = velocity_trimmed:x()
      velocity_east_trimmed  = velocity_trimmed:y()
      velocity_down_trimmed = velocity_trimmed:z()
 
      preload_file(File) --Preloads the first block of data associated with the file

      --Find current time to be used as a reference
      initial_time = millis():tofloat() -- Sets the initial time of the test in ms 

    elseif elapsed_time >= csv_data[#csv_data].time and not csv_fully_loaded then -- Controls when the next block of the csv file is read, time is assumed to be kept in ms 
      preload_file(File)
    elseif elapsed_time < csv_data[#csv_data].time then --If the code has reached this point then then it is ready to find the value to be written
      local vel1, vel2 = find_nearest_data(elapsed_time) --find the two times in the csv closest to the current time
      local delta_velocity_north = vel_amp*interpolate(vel1.time, vel1.X, vel2.time, vel2.X, elapsed_time) -- find the change in velocity from the trimmed condition in the North direction 
      local delta_velocity_east = vel_amp*interpolate(vel1.time, vel1.Y, vel2.time, vel2.Y, elapsed_time) -- find the change in velocity from the trimmed condition in the East direction  
      local delta_velocity_down = vel_amp*interpolate(vel1.time, vel1.Z, vel2.time, vel2.Z, elapsed_time) -- find the change in velocity from the trimmed condition in the Down direction  

      local perturbed_velocity = Vector3f() --Creates a vector 3f object to give to the autopilot to perturb velocity 
      --Insert the values into the the Vector3f object
      perturbed_velocity:x(delta_velocity_north + velocity_north_trimmed)
      perturbed_velocity:y(delta_velocity_east + velocity_east_trimmed)
      perturbed_velocity:y(delta_velocity_down + velocity_down_trimmed)

      --Feed velocity vector back into the autopilot
      vehicle:set_target_velocity_NED(perturbed_velocity)
      
    else --If the code has reached this point csv_fully_loaded has been marked, sets variable to false to stop testing algorithim
      gcs:send_text(6, "Velocity test has finished, ready for next test.")
      File = nil
      vel_Flag = false
    end

  elseif test_Flag then --This will not be present in the final version of the lua script, it is used as a testbed for validation of the algorithim on the static testbed before moving to a simulink dynamics model for validating inputs into a velocity or position hold
    if not File then --Checks if the file is opened and if it isn't it attempts to open it
      csv_fully_loaded = false --Sets the file to not fully loaded before
      open_file(file_name)
      preload_file(File) --Preloads the first block of data associated with the file
      
      initial_time = millis():tofloat() -- Sets the initial time of the test in ms       
    elseif elapsed_time >= csv_data[#csv_data].time and not csv_fully_loaded then -- Controls when the next block of the csv file is read, time is assumed to be kept in ms 
      preload_file(File)
    elseif elapsed_time < csv_data[#csv_data].time then --If the code has reached this point then then it is ready to find the value to be written
      local data1, data2 = find_nearest_data(elapsed_time) --find the two times closest to the current time
      local interpolated_pwm = test_amp*interpolate(data1.time, data1.X, data2.time, data2.X, elapsed_time) --Interpolate between the two data points to find required pwm 
      gcs:send_text(6, "val: " .. tostring(interpolated_pwm) .. ", time: " .. tostring(elapsed_time))
    else --If the code has reached this point csv_fully_loaded has been marked, sets variable to false to stop testing algorithim
      gcs:send_text(6, "Test test has finished, ready for next test.")
      File = nil
      test_Flag = false
    end
  else --If code has reached here no test has been flagged
    if File then --If no test is flagged but the file is still open this will attempt to close the file
      File:close()
    end
  end

  return update, update_rate_ms
end



gcs:send_text(6, "Script Loaded Sucessfully")

return update, update_rate_ms
