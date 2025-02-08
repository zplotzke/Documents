% RUNTRUCKPLATOONTRAINING Main script to run truck platoon LSTM training
%
% Author: zplotzke
% Created: 2025-02-08 04:20:14 UTC

% Create default configuration
config = struct();

% Simulation parameters
config.simulation = struct();
config.simulation.frame_rate = 100;  % Hz
config.simulation.final_time = 6;    % seconds
config.simulation.num_random_simulations = 10;
config.simulation.file_names = struct();
config.simulation.file_names.simulation_data = 'truck_platoon_data.mat';
config.simulation.file_names.lstm_model = 'truck_platoon_lstm.mat';

% Truck parameters
config.truck = struct();
config.truck.num_trucks = 4;         % Number of trucks in platoon
config.truck.initial_speed = 25;     % m/s (approximately 90 km/h)
config.truck.min_safe_distance = 10; % meters

% LSTM network parameters
config.lstm = struct();
config.lstm.hidden_units = 128;
config.lstm.max_epochs = 100;
config.lstm.mini_batch_size = 32;
config.lstm.initial_learn_rate = 0.001;
config.lstm.gradient_threshold = 1;

% Create logger
logger = struct();
logger.info = @(varargin) fprintf([datestr(now, 'yyyy-mm-dd HH:MM:SS'), ' [INFO] ', varargin{1}, '\n'], varargin{2:end});
logger.error = @(varargin) fprintf([datestr(now, 'yyyy-mm-dd HH:MM:SS'), ' [ERROR] ', varargin{1}, '\n'], varargin{2:end});
logger.debug = @(varargin) fprintf([datestr(now, 'yyyy-mm-dd HH:MM:SS'), ' [DEBUG] ', varargin{1}, '\n'], varargin{2:end});

% Run training
try
    trainLSTMNetwork(config, logger);
catch ME
    logger.error('Training failed: %s', ME.message);
    logger.error('Stack trace: %s', getReport(ME));
    rethrow(ME);
end