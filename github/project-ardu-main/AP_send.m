function AP_send(omega_b, attitude, velocity_b, position_e, time)

global u

if isempty(u)
    return
end

persistent past_time
if isempty(past_time)
    past_time = -1;
end

if past_time == time
    return
end
past_time = time;

% Make sure all signals are row vectors
gyro = double(omega_b(:)');
attitude = double(attitude(:)');
velocity = double(velocity_b(:)');
position = double(position_e(:)');

% If you do not have acceleration from the 6DOF block yet
accel_body = [0 0 0];

% Build JSON message for ArduPilot
JSON.timestamp = double(time);

JSON.imu.gyro = gyro;              % [p q r] rad/s
JSON.imu.accel_body = accel_body;  % [ax ay az] m/s^2

JSON.attitude = attitude;          % [phi theta psi] rad
JSON.velocity = velocity;          % [u v w] m/s
JSON.position = position;          % [x y z] m

% Send to ArduPilot
pnet(u,'printf',sprintf('\n%s\n',jsonencode(JSON)));
pnet(u,'writepacket');

end