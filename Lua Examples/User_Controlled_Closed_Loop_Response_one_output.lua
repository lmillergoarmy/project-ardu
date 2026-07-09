--Notes for script usage:
--Remove any header from the csv file
--All time is kept in MS, so format any file to be read accordingly

--NOTES FOR SCRIPT WRITING
--NEED TO SAVE FIXED VELOCITY, POSITION, ECT TO RUN AS BASELINE VALUES FOR THE MULTISINE


--Boolean values controlled by the code
local csv_fully_loaded = false --Allows the code to detect when the csv is finished loading
local test_started = false --Monitors if the code has been started 

--Temporary Boolean Values, intended to be controlled by an external device
local pos_Flag = false --Flags if a Position test is being conducted
local vel_Flag = false --Flags if a velocity test is being conducted

--Dummy variables designed to store data generated in the code
local csv_data = {} --Dummy table to hold the data obtained from the CSV file
local current_index = 1
local initial_time = 0

--Inputs
local line_block = 20 --Designates the maximum size of the table
local file_name = "Chirp_Final_Code_Test" --input the file name, you do not need to include path or file type
--Note: The final version of the code will use one generic set of data with an amplitude of 1 unit

local update_rate_ms = 0 --Determined the update rate of the Update() function
--Note: How this works is that it runs the code then waits the time required
local TIMEOUT_MS = 500

--Uneeded inputs (REMOVE THIS MARKER ONCE FINISHED WITH CODE)
local pos_amp = 1 -- Amplitude of the position multisine
local vel_amp = 1 -- Amplitude of the velocity multisine
local att_amp = 1 -- Amplitude of the Attitude multisine

--Test inputs: Inputs for use on the static testbed for code validation
local test_Flag = true --Flags if a test using pwm is being conducted, used for bug testing before simulink model is active
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
  initial_time = millis():tofloat() -- Sets the initial time of the test in ms 
end



function preload_file(file)
  local final_time = false --Variable to store the final time in a block of lines, boolean used so that it can be checked if these values were overwriten
  local final_val = false --Variable to store the final value in a block of lines, boolean used so that it can be checked if these values were overwriten
  current_index = 1 --Resets the index so that that find_nearest_data knows to start from the bottom of the table

  if csv_data[line_block] then --Checks to see if the data exists 
    final_time = csv_data[line_block].time
    final_val = csv_data[line_block].val
  end
  csv_data = {} -- Resets the table so that the old lines are overwriten as not to bloat size
  if final_time and final_val then --Checks to see if the variables were overwritten
    table.insert(csv_data, {time = final_time, val = final_val}) --Turns the last value of the previous table into the first value of the next table to prevent errors in the linear interpolation function
  end
  -- Read a chunk of lines (e.g., 20 lines at a time) in each cycle

  for i = 1, line_block do
    local line = file:read()
    if line then
      local time_str, val_str = line:match("([^,]+),([^,]+)")
      local time = tonumber(time_str:match("^%s*(.-)%s*$"))  -- Trim and convert to number
      local val = tonumber(val_str:match("^%s*(.-)%s*$"))    -- Trim and convert to number
        if time and val then
          table.insert(csv_data, {time = time, val = val})
        end
    else
      -- Close the file when done
      file:close()
      file = nil --(NOTEL DELETE IF THIS DOESNT CAUSE ERROR BUT THIS MIGHT CAUSE ISSUES ATTEMPTING TO OVERWRITE GLOBAL VARIABLE FILE)
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


    
   if not File then --Checks if the file is opened and if it isn't it attempts to open it
      open_file(file_name)
      preload_file(File) --Preloads the first block of data associated with the file
   end

   local elapsed_time = millis():tofloat() - initial_time --Finds the elapsed time since the file was opened

  --This code uses if statements to determine when the test is started and which one it is
  --NOTE: POTENTIAL ERROR IN USEAGE, IF TEST SWITCHED PREMATURELY THEN IT MIGHT NOT START AT THE CORRECT LOCATION IN CSV
  if pos_Flag then
    gcs:send_text(6, "Position hold not implemented yet") 
  elseif vel_Flag then
    gcs:send_text(6, "Velocity hold not implemented yet")  
  elseif test_Flag then 
    if elapsed_time >= csv_data[#csv_data].time then -- Controls when the next block of the csv file is read, time is assumed to be kept in ms 
      --NOTE MIGHT FLAG ERROR WHEN REACHING THE END OF A SMALLER LINE BLOCK, maybe either add another statement controlling that or fill rest of table with dummy variables equal to the last variable equal to last of smaller table
      preload_file(File)
    else --If the code has reached this point then then it is ready to find the value to be written
      gcs:send_text(6, tostring(elapsed_time))
      local data1, data2 = find_nearest_data(elapsed_time) --find the two times closest to the current time
      local interpolated_pwm = test_amp*interpolate(data1.time, data1.val, data2.time, data2.val, elapsed_time) --Interpolate between the two data points to find required pwm
      local output_pwm = baseline_pwm + interpolated_pwm -- perturb from the initial value to get output to send to drone
      output_pwm = math.floor(output_pwm) -- rounds the value to the nearest whole number
      --ERROR IS FLAGGING
      --Set the motor outputs to the found output pwm
      SRV_Channels:set_output_pwm_chan_timeout(9, output_pwm, TIMEOUT_MS)
      SRV_Channels:set_output_pwm_chan_timeout(10, output_pwm, TIMEOUT_MS)
      SRV_Channels:set_output_pwm_chan_timeout(11, output_pwm, TIMEOUT_MS)
      SRV_Channels:set_output_pwm_chan_timeout(12, output_pwm, TIMEOUT_MS)

    
    end

  end




  return update, update_rate_ms --Temporary return function to create looping structure
end



gcs:send_text(6, "Script Loaded Sucessfully")

return update, update_rate_ms
