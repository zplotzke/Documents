% testPlatoonVisualizer.m
% Test script for PlatoonVisualizer class to simulate exactly one mile travel
%
% Author: zplotzke
% Last Modified: 2025-02-10 04:40:40 UTC

% Clear workspace and close figures
clear;
close all;

try
    % Create configuration structure
    config = struct();

    % Truck configuration
    config.truck = struct(...
        'num_trucks', 4, ...
        'length', [...
        16.5;   % Truck 1: Standard semi-truck
        14.5;   % Truck 2: Shorter semi-truck
        18.0;   % Truck 3: Extended semi-truck
        15.5    % Truck 4: Standard semi-truck
        ], ...
        'initial_speed', 20, ...    % m/s (approximately 72 km/h)
        'desired_gap', 20, ...      % meters between trucks
        'max_relative_velocity', 5);

    % Safety configuration
    config.safety = struct(...
        'min_safe_distance', 10);   % meters

    % Simulation configuration
    config.simulation = struct(...
        'frame_rate', 10);          % frames per second

    % Calculate required time to travel exactly one mile
    one_mile_meters = 1609.34;      % meters
    initial_position = 50;          % Start at 50m to ensure visibility
    required_time = one_mile_meters / config.truck.initial_speed;

    % Set simulation duration for exact one mile travel
    config.simulation.duration = required_time;  % seconds

    % Initialize time vector
    dt = 1/config.simulation.frame_rate;
    t = 0:dt:config.simulation.duration;
    num_steps = length(t);

    % Initialize state structure
    state = struct();
    state.lengths = config.truck.length;

    % Initialize time history
    state.timeHistory = struct();
    state.timeHistory.times = t;

    % Initialize positions (starting with equal spacing)
    state.timeHistory.positions = zeros(config.truck.num_trucks, num_steps);

    % Calculate total platoon length for initial positioning
    total_platoon_length = sum(config.truck.length) + ...
        (config.truck.num_trucks - 1) * config.truck.desired_gap;

    % Start position for lead truck
    lead_truck_start = initial_position + total_platoon_length;

    for i = 1:config.truck.num_trucks
        % Each truck starts behind the previous one with desired gap + truck length
        total_offset = 0;
        for j = 1:i-1
            total_offset = total_offset + config.truck.length(j) + config.truck.desired_gap;
        end

        % Calculate base position (starting from lead truck)
        base_position = lead_truck_start - total_offset;

        % Add small sinusoidal variation to make visualization interesting
        phase = (i-1) * pi/4;      % Different phase for each truck
        amplitude = 0.5;            % Small amplitude for variation (meters)
        frequency = 0.1;            % Low frequency for gentle oscillation (Hz)

        % Position time history with sinusoidal variation
        base_positions = base_position + config.truck.initial_speed * t;
        variations = amplitude * sin(2*pi*frequency*t + phase);
        state.timeHistory.positions(i,:) = base_positions + variations;
    end

    % Initialize velocities (approximately constant with small variations)
    state.timeHistory.velocities = zeros(config.truck.num_trucks, num_steps);
    for i = 1:config.truck.num_trucks
        % Add small sinusoidal variation to velocity
        phase = (i-1) * pi/4;
        amplitude = 0.2;            % Small velocity variation (m/s)
        frequency = 0.1;

        % Velocity time history with sinusoidal variation
        base_velocity = config.truck.initial_speed * ones(1, num_steps);
        variations = amplitude * sin(2*pi*frequency*t + phase);
        state.timeHistory.velocities(i,:) = base_velocity + variations;
    end

    % Create visualizer
    visualizer = PlatoonVisualizer(config);

    % Debug: Print first and last positions for each truck
    fprintf('Position data verification:\n');
    for i = 1:config.truck.num_trucks
        first_pos = state.timeHistory.positions(i,1);
        last_pos = state.timeHistory.positions(i,end);
        fprintf('Truck %d: Start = %.2f, End = %.2f, Total movement = %.2f meters\n', ...
            i, first_pos, last_pos, last_pos - first_pos);
    end

    % Visualize results
    visualizer.visualize(state);

catch ME
    % Error handling with detailed output
    fprintf('Error testing PlatoonVisualizer:\n');
    warning(ME.identifier, '%s', ME.message);
    fprintf('Error Identifier: %s\n', ME.identifier);
    fprintf('Stack Trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  File: %s\n  Line: %d\n  Name: %s\n\n', ...
            ME.stack(i).file, ...
            ME.stack(i).line, ...
            ME.stack(i).name);
    end
end