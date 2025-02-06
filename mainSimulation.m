% mainSimulation.m

clear; close all; clc;

%% Run Random Simulations
runRandomSimulations(100, 'simulation_data.mat');

%% Main Script

% Parallel Pool Setup
setupParallelPool(2);

% Ensure cleanup on exit
cleanupObj = onCleanup(@() cleanupParallelPool());

try
    % Scenario Setup for main simulation
    [N_trucks, tf, fR, dt, time, distance_analysis, trackWidth, laneMargin, truck_params, parameters] = initializeScenario();

    % Simulation
    [TSPAN, states_initial_condition] = initializeSimulation(truck_params, time);
    [TOUT, YOUT] = runSimulation(TSPAN, states_initial_condition, parameters);

    % Retrieve states
    [truck_positions, truck_speeds] = retrieveStates(YOUT, N_trucks);

    % Calculate accelerations and jerks
    [truck_accs, truck_jerks] = calculateAccAndJerk(TOUT, YOUT, parameters, N_trucks);

    % Calculate distances between trucks
    distances = calculateDistances(truck_positions, truck_params.length, N_trucks);

    % Kalman Filter Initialization
    [x_est, P_est, A, B, C, Q, R] = initializeKalmanFilter(truck_params, dt);

    % Simulation Loop with Kalman Filter
    [truck_1_position_est, truck_1_speed_est] = runKalmanFilter(TOUT, truck_positions, x_est, P_est, A, B, C, Q, R);

    % Results
    createTruckPlatoonVideo(N_trucks, TOUT, time, truck_positions, truck_speeds, truck_accs, distances, trackWidth, laneMargin, distance_analysis, truck_params, truck_jerks);

catch ME
    disp('An error occurred:');
    disp(ME.message);
end

cleanupParallelPool();

%% Function Definitions
function [N_trucks, tf, fR, dt, time, distance_analysis, trackWidth, laneMargin, truck_params, parameters] = initializeScenario()

% Number of trucks
N_trucks                = 4;

% Simulation time parameters
tf                      = 40;                      % Final time [s]
fR                      = 30;                      % Frame rate [fps]
dt                      = 1/fR;                    % Time resolution [s]
time                    = linspace(0, tf, tf*fR);  % Time vector [s]

% Road parameters
distance_analysis       = 150;                     % Distance of analysis [m]
trackWidth              = 20;                      % Track width [m]
laneMargin              = 2;                       % Lane margin [m]

% Truck parameters
truck_length            = 20;                      % Length of each truck [m]
truck_width             = 4;                       % Width of each truck [m]
truck_initial_speed     = 72/3.6;                  % Initial speed of each truck [m/s]
truck_initial_positions = [150, 120, 80, 40];      % Initial positions of the trucks [m]

% Group truck parameters into a struct
truck_params = struct(...
    'length', truck_length, ...
    'width', truck_width, ...
    'initial_speed', truck_initial_speed, ...
    'initial_positions', truck_initial_positions ...
    );

% Parameters struct for ode45
parameters = struct(...
    'truck_1_length', truck_length, ...
    'truck_2_length', truck_length, ...
    'truck_3_length', truck_length, ...
    'truck_4_length', truck_length ...
    );
end

function [TSPAN, states_initial_condition] = initializeSimulation(truck_params, time)
TSPAN = time;

% Initialize states: [position, speed] pairs for each truck
states_initial_condition = reshape([truck_params.initial_positions; repmat(truck_params.initial_speed, 1, length(truck_params.initial_positions))], 1, []);

% Debug statement
disp('Initial States:');
disp(states_initial_condition);
end

function [TOUT, YOUT] = runSimulation(TSPAN, states_initial_condition, parameters)
% Set ODE solver options
options = odeset('RelTol', 1e-9, 'AbsTol', 1e-9);

% Run the simulation using ode45
[TOUT, YOUT] = ode45(@(t, z) simulateTruckPlatoon(t, z, parameters), TSPAN, states_initial_condition, options);

% Check for NaNs in simulation output
if any(isnan(YOUT(:)))
    warning('NaNs detected in simulation output.');
end
end

function [truck_positions, truck_speeds] = retrieveStates(YOUT, N_trucks)

% Initialize cell arrays to store positions and speeds
truck_positions = cell(1, N_trucks);
truck_speeds = cell(1, N_trucks);

% Extract positions and speeds for each truck
for i = 1:N_trucks
    truck_positions{i} = YOUT(:, 2*i-1);
    truck_speeds{i} = YOUT(:, 2*i);
end
end

function setupParallelPool(numWorkers)
% Check for an existing parallel pool
poolobj = gcp('nocreate');

% Delete the existing parallel pool if it exists
if ~isempty(poolobj)
    delete(poolobj);
end

% Start a new parallel pool with the specified number of workers
parpool('local', numWorkers);
end

function [truck_accs, truck_jerks] = calculateAccAndJerk(TOUT, YOUT, parameters, N_trucks)

% Preallocate acceleration and jerk arrays
truck_accs = zeros(N_trucks, length(TOUT));
truck_jerks = zeros(N_trucks, length(TOUT));

% Calculate accelerations in parallel
parfor i = 1:length(TOUT)
    dz = simulateTruckPlatoon(TOUT(i), YOUT(i, :), parameters);
    for j = 1:N_trucks
        truck_accs(j, i) = dz(2*j);
    end
end

% Pre-compute time step differences
dt = diff(TOUT);

% Calculate jerks in parallel
parfor i = 2:length(TOUT)
    for j = 1:N_trucks
        truck_jerks(j, i) = (truck_accs(j, i) - truck_accs(j, i-1)) / dt(i-1);
    end
end
end

function distances = calculateDistances(truck_positions, truck_length, N_trucks)

% Initialize cell array to store distances
distances = cell(1, N_trucks-1);

% Calculate distances between consecutive trucks
for i = 1:N_trucks-1
    distances{i} = truck_positions{i} - truck_positions{i+1} - truck_length;
end
end

function [x_est, P_est, A, B, C, Q, R] = initializeKalmanFilter(truck_params, dt)

% Initialize state estimate
x_est = [truck_params.initial_positions(1); truck_params.initial_speed];

% Initialize covariance estimate
P_est = eye(2);

% Define state-space model matrices
A     = [1 dt; 0 1];      % State transition matrix
B     = [0; dt];          % Control input matrix
C     = [1 0];            % Measurement matrix
Q     = [1e-5 0; 0 1e-5]; % Process noise covariance
R     = 1e-2;             % Measurement noise covariance

end

function [truck_1_position_est, truck_1_speed_est] = runKalmanFilter(TOUT, truck_positions, x_est, P_est, A, B, C, Q, R)
% Preallocate arrays for estimated states
truck_1_position_est = zeros(1, length(TOUT));
truck_1_speed_est = zeros(1, length(TOUT));

% Run the Kalman filter for each time step in parallel
parfor i = 1:length(TOUT)
    % Initialize state and covariance estimates for each iteration
    x_est_i = x_est;
    P_est_i = P_est;

    % Control input (e.g., from your control algorithm)
    control_input = 0;  % Replace with your actual control input

    % Measurement (e.g., from your sensors)
    measurement = truck_positions{1}(i);  % Replace with your actual measurement

    % Update the Kalman filter
    [x_est_i, P_est_i] = kalmanFilter(x_est_i, P_est_i, control_input, measurement, A, B, C, Q, R);

    % Store the estimated states
    truck_1_position_est(i) = x_est_i(1);
    truck_1_speed_est(i) = x_est_i(2);
end
end

function createTruckPlatoonVideo(N_trucks, TOUT, time, truck_positions, truck_speeds, truck_accs, distances, trackWidth, laneMargin, distance_analysis, truck_dimensions, truck_jerks)

% Colormap for trucks
c = cool(N_trucks);

% Set up figure
figureHandle = figure;
set(figureHandle, 'Position', [50 50 1280 720]); % 720p

% Create and open video writer object
v = VideoWriter('truck_platoon_string.avi');
v.Quality = 100;
open(v);

% Sampling frequency for the warning tone
fs = 44100;
duration = 1/30; % Duration of the warning tone to match frame rate

% Log file for warnings
logFile = 'warning_log.txt';
if exist(logFile, 'file')
    delete(logFile);
end

% Pre-compute maximum values for plotting
position_max = max(truck_positions{1});
speed_max    = max(cellfun(@max, truck_speeds));
acc_min      = min(truck_accs(:));
acc_max      = max(truck_accs(:));
dist_max     = max(cellfun(@max, distances));
jerk_min     = min(truck_jerks(:));
jerk_max     = max(truck_jerks(:));

for i = 1:length(time)
    % Plot speeds
    subplot(4, 2, 1);
    hold on; grid on;
    set(gca, 'xlim', [0 TOUT(end)], 'ylim', [0 1.2*speed_max]);
    cla;
    for j = 1:N_trucks
        plot(TOUT, truck_speeds{j}, 'color', c(j, :));
    end
    plot([time(i) time(i)], [0 1.2*speed_max], 'k--');
    xlabel('Time [s]');
    ylabel('Speed [m/s]');
    title('Speed');
    legend(arrayfun(@(x) ['Truck ' num2str(x)], 1:N_trucks, 'UniformOutput', false), 'location', 'SouthEast');

    % Plot positions
    subplot(4, 2, 2);
    hold on; grid on;
    set(gca, 'xlim', [0 TOUT(end)], 'ylim', [0 1.2*position_max]);
    cla;
    for j = 1:N_trucks
        plot(TOUT, truck_positions{j}, 'color', c(j, :));
    end
    plot([time(i) time(i)], [0 1.2*position_max], 'k--');
    xlabel('Time [s]');
    ylabel('Position [m]');
    title('Position');
    legend(arrayfun(@(x) ['Truck ' num2str(x)], 1:N_trucks, 'UniformOutput', false), 'location', 'SouthEast');

    % Plot accelerations
    subplot(4, 2, 3);
    hold on; grid on;
    set(gca, 'xlim', [0 TOUT(end)], 'ylim', [1.2*acc_min 1.2*acc_max]);
    cla;
    for j = 1:N_trucks
        plot(TOUT, truck_accs(j, :), 'color', c(j, :));
    end
    plot([time(i) time(i)], [1.2*acc_min 1.2*acc_max], 'k--');
    xlabel('Time [s]');
    ylabel('Acceleration [m/s^2]');
    title('Acceleration');
    legend(arrayfun(@(x) ['Truck ' num2str(x)], 1:N_trucks, 'UniformOutput', false), 'location', 'SouthEast');

    % Plot separation distances
    subplot(4, 2, 4);
    hold on; grid on;
    set(gca, 'xlim', [0 TOUT(end)], 'ylim', [0 1.2*dist_max]);
    cla;
    for j = 1:N_trucks-1
        plot(TOUT, distances{j}, 'color', c(j+1, :));
    end
    plot([time(i) time(i)], [0 1.2*dist_max], 'k--');
    xlabel('Time [s]');
    ylabel('Distance [m]');
    title('Separation Distance');
    legend(arrayfun(@(x) ['Trucks ' num2str(x) ' & ' num2str(x+1)], 1:N_trucks-1, 'UniformOutput', false), 'location', 'SouthEast');

    % Plot jerks
    subplot(4, 2, 5);
    hold on; grid on;
    set(gca, 'xlim', [0 TOUT(end)], 'ylim', [1.2*jerk_min 1.2*jerk_max]);
    cla;
    for j = 1:N_trucks
        plot(TOUT, truck_jerks(j, :), 'color', c(j, :));
    end
    plot([time(i) time(i)], [1.2*jerk_min 1.2*jerk_max], 'k--');
    xlabel('Time [s]');
    ylabel('Jerk [m/s^3]');
    title('Jerk');
    legend(arrayfun(@(x) ['Truck ' num2str(x)], 1:N_trucks, 'UniformOutput', false), 'location', 'SouthEast');

    % Plot truck positions on the road
    subplot(4, 2, 7:8);
    hold on; axis equal;
    cla;

    % Position of the leading truck at instant [m]
    truck_positions_inst = cellfun(@(x) x(i), truck_positions);

    sideMarkingsX = [truck_positions_inst(1)-distance_analysis truck_positions_inst(1)];
    set(gca, 'xlim', [truck_positions_inst(1)-distance_analysis truck_positions_inst(1)], 'ylim', [-trackWidth/2-laneMargin +trackWidth/2+laneMargin]);

    plot(sideMarkingsX, [+trackWidth/2 +trackWidth/2], 'k--'); % Left marking
    plot(sideMarkingsX, [-trackWidth/2 -trackWidth/2], 'k--'); % Right marking

    % Plotting trucks
    for j = 1:N_trucks
        truck_dimension_X = [truck_positions_inst(j) truck_positions_inst(j) truck_positions_inst(j)-truck_dimensions.length truck_positions_inst(j)-truck_dimensions.length];
        truck_dimension_Y = [+truck_dimensions.width/2 -truck_dimensions.width/2 -truck_dimensions.width/2 +truck_dimensions.width/2];
        fill(truck_dimension_X, truck_dimension_Y, c(j, :));
    end
    xlabel('Lon. distance [m]');
    ylabel('Lat. distance [m]');

    % Call the warning function
    [warning_level, warning_message] = warnTruck(truck_positions_inst, repmat(truck_dimensions.length, 1, N_trucks), fs, duration, logFile, truck_jerks(1, i), truck_jerks(2, i), truck_jerks(3, i), truck_jerks(4, i));

    % Display visual warning if necessary
    if warning_level > 0
        switch warning_level
            case 1
                warning_color = 'black';
            case 2
                warning_color = [1, 0.5, 0]; % RGB triplet for orange
            case 3
                warning_color = 'red';
        end
        text(mean(get(gca, 'xlim')), -trackWidth/2 - laneMargin - 10, warning_message, ...
            'Color', warning_color, 'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        rectangle('Position', [truck_positions_inst(1) - distance_analysis, -trackWidth/2 - laneMargin, distance_analysis, trackWidth + 2*laneMargin], ...
            'EdgeColor', warning_color, 'LineWidth', 2, 'LineStyle', '--');
    end

    % Capture frame for video
    frame = getframe(figureHandle);
    writeVideo(v, frame);
end
close(v);
end

function [warning_level, warning_message] = warnTruck(truck_positions, truck_lengths, fs, duration, logFile, truck_1_jerk, truck_2_jerk, truck_3_jerk, truck_4_jerk)

% Parameters
warning_distances = [20, 15, 10];                  % Warning distance thresholds [m]
jerk_thresholds   = [0.25, 0.5, 1];                % Warning jerk thresholds [m/s^3]
min_distance      = 0.1;                           % Minimum distance to avoid division by zero [m]
frequencies       = [1000, 1500, 2000];            % Frequencies for different levels [Hz]
warning_colors    = {'black', [1, 0.5, 0], 'red'}; % Colors for warning levels

% Calculate distances between trucks
dist_1_2 = truck_positions(1) - truck_positions(2) - truck_lengths(1);
dist_2_3 = truck_positions(2) - truck_positions(3) - truck_lengths(2);
dist_3_4 = truck_positions(3) - truck_positions(4) - truck_lengths(3);

% Check distances and determine warning level
distances = [dist_1_2, dist_2_3, dist_3_4];
[min_distance_val, idx] = min(distances);
warning_level_distance = find(min_distance_val < warning_distances, 1);

% Check jerks and determine warning level
jerks = [truck_1_jerk, truck_2_jerk, truck_3_jerk, truck_4_jerk];
warning_level_jerk = 0;
for jerk = jerks
    if abs(jerk) > jerk_thresholds(3)
        warning_level_jerk = 3;
        break;
    elseif abs(jerk) > jerk_thresholds(2)
        warning_level_jerk = max(warning_level_jerk, 2);
    elseif abs(jerk) > jerk_thresholds(1)
        warning_level_jerk = max(warning_level_jerk, 1);
    end
end

% Determine final warning level
warning_level = max([warning_level_distance, warning_level_jerk]);

% Ensure warning_level is valid
if isempty(warning_level) || warning_level < 1 || warning_level > 3
    warning_level = 0;
end

warning_message = '';
if warning_level > 0
    % Generate the warning tone
    frequency = frequencies(warning_level);
    t = 0:1/fs:duration;
    tone = sin(2 * pi * frequency * t);
    sound(tone, fs);

    % Print the warning message
    truck_pairs = {'Truck 1 and Truck 2', 'Truck 2 and Truck 3', 'Truck 3 and Truck 4'};
    if ~isempty(warning_level_distance)
        distance_warning_message = sprintf('Distance between %s is %.2f meters.', truck_pairs{idx}, min_distance_val);
    else
        distance_warning_message = '';
    end

    if warning_level_jerk > 0
        [~, truck_idx] = max(abs(jerks));
        jerk_warning_message = sprintf('Jerk of Truck %d is %.2f m/s^3.', truck_idx, jerks(truck_idx));
    else
        jerk_warning_message = '';
    end

    warning_message = sprintf('Warning Level %d: %s %s', ...
        warning_level, distance_warning_message, jerk_warning_message);

    % Log the warning
    if nargin > 5
        logMessage = sprintf('%s - %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), warning_message);
        fid = fopen(logFile, 'a');
        fprintf(fid, logMessage);
        fclose(fid);
    end
end
end

function dz = simulateTruckPlatoon(t, z, parameters)
% Parameters
truck_lengths = [parameters.truck_1_length, parameters.truck_2_length, parameters.truck_3_length];

% Retrieving states
truck_positions = z(1:2:end);
truck_speeds    = z(2:2:end);

% Sensors
distances_preceding = truck_positions(1:end-1) - truck_positions(2:end) - truck_lengths';
speeds_preceding    = truck_speeds(1:end-1);

% Initialize state derivatives
dz = zeros(8, 1);

% Dynamic model for the leading truck
dz(1:2) = truckModel(t, z(1:2), 1, 1);

% Dynamic models for the following trucks
for i = 2:4
    sensors.distance_preceding = distances_preceding(i-1);
    sensors.speed_preceding = speeds_preceding(i-1);
    dz(2*i-1:2*i) = truckModel(t, z(2*i-1:2*i), i, sensors);
end

% Check for NaNs in state derivatives
if any(isnan(dz))
    warning('NaNs detected in state derivatives.');
end
end

function dstates = truckModel(~, states, truck_flag, truck_sensors)
% Parameters
m   = 40000;                                            % Mass [kg]
g   = 9.81;                                             % Gravity [m/s^2]
Cd  = 0.78;                                             % Drag coefficient [-]
A   = 10;                                               % Frontal area [m^2]
rho = 1;                                                % Air density [kg/m^3]

% Precompute constants
C   = 0.5 * rho * Cd * A;                               % Drag coefficient term
Gx  = m * g * sin(0);                                   % Gravity force component along the road [N]

% States
V   = states(2);                                        % Velocity [m/s]

% Drag Resistance
Dx  = C * V^2;                                          % Drag force [N]

if truck_flag == 1
    % Cruise Control (CC)
    V_r = 20;                                           % Reference speed [m/s]
    Kp  = 500;                                          % Proportional gain for CC
    Ft  = Kp * (V_r - V) + Dx;                          % Longitudinal force [N]
else
    % Adaptive Cruise Control (ACC)
    th  = 1.0;                                          % Time gap [s]
    desired_distance = th * V;                          % Desired distance to preceding vehicle [m]
    Kp  = 10000;                                        % Proportional gain for ACC
    Kd  = 10000;                                        % Derivative gain for ACC
    Ft  = Kp * (truck_sensors.distance_preceding - desired_distance) + ...
        Kd * (truck_sensors.speed_preceding - V) + Dx;  % Longitudinal force [N]
end

% Vehicle Dynamics
dstates = [V; (Ft - Dx - Gx) / m];                      % Derivatives of position and velocity

% Check for NaNs in state derivatives
if any(isnan(dstates))
    warning('NaNs detected in state derivatives.');
end
end

function [x_est, P_est] = kalmanFilter(x_est, P_est, u, z, A, B, C, Q, R)
% Prediction step
x_pred = A * x_est + B * u;
P_pred = A * P_est * A' + Q;

% Update step
K = P_pred * C' / (C * P_pred * C' + R);
x_est = x_pred + K * (z - C * x_pred);
P_est = (eye(size(K,1)) - K * C) * P_pred;
end

function runRandomSimulations(numSimulations, saveFileName)
if nargin < 1
    numSimulations = 100;
end
if nargin < 2
    saveFileName = 'simulation_data.mat';
end

% Initialize storage with correct shape
inputs = zeros(1, 8, numSimulations); % Initial conditions per simulation
outputs = zeros(1200, 8, numSimulations); % Time-series outputs

setupParallelPool(4);
cleanupObj = onCleanup(@() cleanupParallelPool());

parfor simIdx = 1:numSimulations
    % Generate random initial conditions
    [N_trucks, tf, fR, dt, time, distance_analysis, trackWidth, laneMargin, truck_params, parameters] = initializeScenario();
    truck_params.initial_positions = rand(1, N_trucks) * 200;
    truck_params.initial_speed = rand * 30;

    % Initialize and run simulation
    [TSPAN, states_initial_condition] = initializeSimulation(truck_params, time);
    [TOUT, YOUT] = runSimulation(TSPAN, states_initial_condition, parameters);

    % Store data in 3D format
    inputs(:,:,simIdx) = states_initial_condition;
    outputs(:,:,simIdx) = YOUT;
end

% Debugging: Print final data sizes before saving
fprintf('Final Input Size: %s\n', mat2str(size(inputs)));
fprintf('Final Output Size: %s\n', mat2str(size(outputs)));

% Ensure data is correctly formatted
expectedInputSize = [1, 8, numSimulations];
expectedOutputSize = [1200, 8, numSimulations];

if ~isequal(size(inputs), expectedInputSize)
    error('Mismatch in input dimensions! Expected %s but got %s', mat2str(expectedInputSize), mat2str(size(inputs)));
end

if ~isequal(size(outputs), expectedOutputSize)
    error('Mismatch in output dimensions! Expected %s but got %s', mat2str(expectedOutputSize), mat2str(size(outputs)));
end

% Save properly formatted data
save(saveFileName, 'inputs', 'outputs');
fprintf('Data from %d simulations saved to %s.\n', numSimulations, saveFileName);
end

function cleanupParallelPool()
% Cleanup parallel pool
poolobj = gcp('nocreate');
if ~isempty(poolobj)
    delete(poolobj);
end
end