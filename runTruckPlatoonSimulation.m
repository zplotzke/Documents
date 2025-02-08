function runTruckPlatoonSimulation
% RUNTRUCKPLATOONSIMULATION Main entry point for truck platoon simulation
%
% Author: zplotzke
% Created: 2025-02-08 03:45:27 UTC

try
    % Load configuration
    config = loadConfig();

    % Create and run simulation
    sim = mainSimulation(config);
    sim.run();

catch ME
    fprintf('Error: %s\n', ME.message);
    fprintf('Stack trace: %s\n', getReport(ME));
end
end

function config = loadConfig()
% Load and return configuration parameters
config.truck.num_trucks = 4;
config.truck.length = 10;  % meters
config.truck.initial_speed = 20;  % m/s
config.truck.desired_gap = 10;  % meters

config.safety.min_safe_distance = 10;  % meters
config.safety.max_acceleration = 2;  % m/s^2
config.safety.max_jerk = 0.5;  % m/s^3
config.safety.warning_frequencies = [0.1, 0.1, 0.1, 0.1];  % How often to check each type (seconds)
config.safety.max_relative_velocity = 5;  % m/s - moved from truck to safety config

config.simulation.frame_rate = 10;  % Hz
config.simulation.final_time = 60;  % seconds
config.simulation.num_random_simulations = 10;

config.lstm.hidden_units = 100;
config.lstm.max_epochs = 100;
config.lstm.mini_batch_size = 32;
config.lstm.initial_learn_rate = 0.001;
config.lstm.gradient_threshold = 1;

% File names for saving/loading data
config.simulation.file_names.simulation_data = 'simulation_data.mat';
config.simulation.file_names.lstm_model = 'lstm_model.mat';
end