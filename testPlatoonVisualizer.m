% TESTPLATOONVISUALIZER Test script for PlatoonVisualizer class
%
% Tests visualization of a 4-truck platoon with centered initial view
%
% Author: zplotzke
% Last Modified: 2025-02-09 21:54:56 UTC

% Create configuration structure for 4 trucks
config.truck.num_trucks = 4;
config.truck.length = [15 15 15 15];    % meters - all trucks same length
config.truck.initial_speed = 20;        % m/s
config.truck.desired_gap = 20;          % meters
config.safety.min_safe_distance = 10;   % meters
config.simulation.frame_rate = 10;      % Hz
config.truck.max_relative_velocity = 5;  % m/s

% Create visualizer
visualizer = PlatoonVisualizer(config);

% Create simulated state data
% Calculate initial positions to center the platoon in the view window
total_platoon_length = sum(config.truck.length) + ...
                      (config.truck.num_trucks - 1) * config.truck.desired_gap;
view_center = 200;  % Center point for better initial visibility
start_position = view_center + total_platoon_length/2;  % Position of lead truck

% Initialize positions array
positions = zeros(config.truck.num_trucks, 1);

% Calculate positions for each truck, starting from the lead truck
for i = 1:config.truck.num_trucks
    if i == 1
        positions(i) = start_position;
    else
        % Position each following truck based on previous truck's position
        positions(i) = positions(i-1) - (config.truck.length(i-1) + config.truck.desired_gap);
    end
end

% Create simulated time history (80 seconds of data to travel ~1 mile)
t = 0:0.1:80;
num_steps = length(t);

% Initialize state structure
state.positions = positions;
state.lengths = config.truck.length;
state.timeHistory.times = t;
state.timeHistory.positions = zeros(config.truck.num_trucks, num_steps);
state.timeHistory.velocities = zeros(config.truck.num_trucks, num_steps);

% Simulate movement over 1 mile with slight variations between trucks
for i = 1:num_steps
    % Update positions with slight variations in speed for each truck
    for j = 1:config.truck.num_trucks
        % Base velocity with small sinusoidal variation
        % Different phase for each truck to create natural movement
        v = config.truck.initial_speed + sin(t(i) + j*pi/4)*0.5;
        
        % Update position
        if i > 1
            state.timeHistory.positions(j,i) = state.timeHistory.positions(j,i-1) + ...
                v * (t(i) - t(i-1));
        else
            state.timeHistory.positions(j,i) = positions(j);
        end
        
        % Store velocity
        state.timeHistory.velocities(j,i) = v;
    end
end

% Update current positions to final positions
state.positions = state.timeHistory.positions(:,end);

% Visualize simulation
visualizer.visualize(state);