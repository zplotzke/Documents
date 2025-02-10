% testPlatoonVisualizer.m
% Test script for PlatoonVisualizer class to simulate exactly one mile travel
%
% Author: zplotzke
% Last Modified: 2025-02-10 18:49:21 UTC

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
        'max_relative_velocity', 5); % m/s

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

    % Initialize state structure with complete data
    state = struct();
    state.lengths = config.truck.length;
    state.timeHistory = struct();
    state.timeHistory.times = t;
    state.timeHistory.positions = zeros(config.truck.num_trucks, num_steps);
    state.timeHistory.velocities = zeros(config.truck.num_trucks, num_steps);
    state.timeHistory.accelerations = zeros(config.truck.num_trucks, num_steps);
    state.timeHistory.jerks = zeros(config.truck.num_trucks, num_steps);

    % Calculate total platoon length for initial positioning
    total_platoon_length = sum(config.truck.length) + ...
        (config.truck.num_trucks - 1) * config.truck.desired_gap;

    % Start position for lead truck
    lead_truck_start = initial_position + total_platoon_length;

    % Initialize position and velocity data for each truck
    for i = 1:config.truck.num_trucks
        % Calculate base position for each truck
        total_offset = 0;
        for j = 1:i-1
            total_offset = total_offset + config.truck.length(j) + config.truck.desired_gap;
        end
        base_position = lead_truck_start - total_offset;

        % Add sinusoidal variation to make visualization interesting
        phase = (i-1) * pi/4;      % Different phase for each truck
        pos_amplitude = 0.5;        % Small amplitude for position variation (meters)
        vel_amplitude = 0.2;        % Small amplitude for velocity variation (m/s)
        frequency = 0.1;            % Low frequency for gentle oscillation (Hz)

        % Calculate position and velocity time histories with variations
        base_positions = base_position + config.truck.initial_speed * t;
        pos_variations = pos_amplitude * sin(2*pi*frequency*t + phase);
        state.timeHistory.positions(i,:) = base_positions + pos_variations;

        base_velocity = config.truck.initial_speed * ones(1, num_steps);
        vel_variations = vel_amplitude * sin(2*pi*frequency*t + phase);
        state.timeHistory.velocities(i,:) = base_velocity + vel_variations;

        % Calculate accelerations from velocity changes
        state.timeHistory.accelerations(i,1:end-1) = diff(state.timeHistory.velocities(i,:)) ./ dt;
        state.timeHistory.accelerations(i,end) = state.timeHistory.accelerations(i,end-1);

        % Calculate jerks from acceleration changes
        state.timeHistory.jerks(i,1:end-1) = diff(state.timeHistory.accelerations(i,:)) ./ dt;
        state.timeHistory.jerks(i,end) = state.timeHistory.jerks(i,end-1);
    end

    % Debug: Print first and last positions for each truck
    fprintf('Position data verification:\n');
    for i = 1:config.truck.num_trucks
        first_pos = state.timeHistory.positions(i,1);
        last_pos = state.timeHistory.positions(i,end);
        fprintf('Truck %d: Start = %.2f, End = %.2f, Total movement = %.2f meters\n', ...
            i, first_pos, last_pos, last_pos - first_pos);
    end

    % Create and run visualizer
    visualizer = PlatoonVisualizer(config);
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