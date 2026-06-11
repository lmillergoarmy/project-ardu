function [pwm, reset] = AP_receve(time)
% Receives 16 PWM outputs from ArduPilot SITL JSON interface

global u
persistent connected frame_time last_sim_time frame_count last_SITL_frame past_time

% Default outputs
pwm = zeros(1,16);
reset = false;

% Initialize UDP socket
if isempty(u) || time == 0
    try
        pnet('closeall');
    catch
    end

    u = pnet('udpsocket',9002);
    pnet(u,'setwritetimeout',1);
    pnet(u,'setreadtimeout',0);

    connected = false;
    frame_time = tic;
    last_sim_time = 0;
    frame_count = 0;
    last_SITL_frame = -1;
    past_time = -1;

    fprintf('Waiting for ArduPilot SITL on UDP port 9002...\n');
end

% Avoid repeated time calls
if past_time == time
    return;
end
past_time = time;

bytes_expected = 4 + 4 + 16*2;

% Wait for packet
while true
    in_bytes = pnet(u,'readpacket',bytes_expected);

    if in_bytes <= 0
        pause(0.001);
        continue;
    end

    if in_bytes < bytes_expected
        continue;
    end

    % Read packet
    magic = pnet(u,'read',1,'UINT16','intel');

    % This value is unused, but Simulink does not like "~ ="
    unused_rate = pnet(u,'read',1,'UINT16','intel');

    SITL_frame = pnet(u,'read',1,'UINT32','intel');
    pwm = double(pnet(u,'read',16,'UINT16','intel'))';

    % Check magic number
    if magic ~= 18458
        warning('Incorrect magic value from ArduPilot');
        pwm = zeros(1,16);
        continue;
    end

    % Check frame order
    if SITL_frame < last_SITL_frame
        connected = false;
        reset = true;
        fprintf('Controller reset detected\n');
    elseif SITL_frame == last_SITL_frame
        continue;
    elseif SITL_frame ~= last_SITL_frame + 1 && connected
        fprintf('Missed %i input frames\n', SITL_frame - last_SITL_frame - 1);
    end

    last_SITL_frame = SITL_frame;
    break;
end

% Print connection info once
if ~connected
    connected = true;
    [ip, port] = pnet(u,'gethost');
    fprintf('Connected to %i.%i.%i.%i:%i\n', ip, port);
end

% FPS print
frame_count = frame_count + 1;
print_frame_count = 1000;

if rem(frame_count, print_frame_count) == 0
    total_time = toc(frame_time);
    frame_time = tic;
    sim_time = time - last_sim_time;
    last_sim_time = time;
    time_ratio = sim_time / total_time;

    fprintf('%0.2f fps, %0.2f%% realtime\n', ...
        print_frame_count / total_time, time_ratio * 100);
end

end