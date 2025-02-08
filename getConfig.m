function config = getConfig()
% GETCONFIG Returns configuration structure for truck platoon simulation
%
% Author: zplotzke
% Created: 2025-02-08 03:00:09 UTC

% Get timestamp for file naming
timestamp = datetime('now', 'Format', 'yyyy-MM-dd_HH-mm-ss');

% Truck configuration
config.truck.num_trucks = 4;            ... % Number of trucks in platoon
    config.truck.length = 16.5;             ... % Length of each truck (m)
    config.truck.initial_speed = 22.22;     ... % Initial speed (m/s) [80 km/h]
    config.truck.desired_gap = 20.0;        ... % Desired gap between trucks (m)
    config.truck.max_relative_velocity = 5.0;    % Maximum relative velocity (m/s)

% Safety parameters
config.safety.min_safe_distance = 10.0; ... % Minimum safe distance between trucks (m)
    config.safety.max_acceleration = 2.0;    ... % Maximum acceleration (m/s^2)
    config.safety.max_deceleration = -6.0;  ... % Maximum deceleration (m/s^2)
    config.safety.max_jerk = 1.0;               % Maximum jerk (m/s^3)

% Warning frequencies for different safety violations (Hz)
config.safety.warning_frequencies = [
    2.0;    % Distance warning frequency
    1.0;    % Velocity warning frequency
    1.5;    % Acceleration warning frequency
    0.5     % Jerk warning frequency
    ];

% Simulation parameters
config.simulation.frame_rate = 10;      ... % Simulation frame rate (Hz)
    config.simulation.final_time = 60;      ... % Simulation duration (s)
    config.simulation.num_random_simulations = 10; % Number of random simulations for training

% LSTM network parameters
config.lstm.hidden_units = 100;         ... % Number of hidden units
    config.lstm.max_epochs = 100;           ... % Maximum training epochs
    config.lstm.mini_batch_size = 32;       ... % Mini-batch size for training
    config.lstm.initial_learn_rate = 0.001; ... % Initial learning rate
    config.lstm.gradient_threshold = 1;          % Gradient threshold for clipping

% Visualization settings
config.visualization.enable = true;      ... % Enable visualization
    config.visualization.save_video = false;     % Save visualization as video

% File paths and names
base_dir = 'data';
if ~exist(base_dir, 'dir')
    mkdir(base_dir);
end

sim_dir = fullfile(base_dir, char(timestamp));
if ~exist(sim_dir, 'dir')
    mkdir(sim_dir);
end

config.simulation.file_names.simulation_data = fullfile(sim_dir, 'simulation_data.mat');
config.simulation.file_names.lstm_model = fullfile(sim_dir, 'lstm_model.mat');
config.simulation.file_names.log_file = fullfile(sim_dir, 'simulation.log');
config.visualization.video_filename = fullfile(sim_dir, 'simulation.mp4');
end