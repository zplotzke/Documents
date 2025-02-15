function config = getConfig()
% GETCONFIG Returns configuration settings for the application
%
% Returns a configuration structure with required settings for truck platoon simulation.
% All sections are required by the test suite and have specific validation ranges.
%
% Author: zplotzke
% Last Modified: 2025-02-15 04:41:01 UTC
% Version: 1.0.10

% Initialize configuration structure
config = struct();

% Logging configuration
config.logging = struct(...
    'file_logging', false, ...      % Enable file logging
    'console_logging', true, ...    % Enable console logging
    'log_level', 'INFO', ...       % Default log level
    'log_dir', fullfile(pwd, 'logs') ... % Log directory
    );

% Paths configuration
config.paths = struct(...
    'data_dir', fullfile(pwd, 'data'), ...     % Data directory
    'model_dir', fullfile(pwd, 'models'), ...  % Model directory
    'log_dir', fullfile(pwd, 'logs') ...      % Log directory
    );

% Safety configuration
config.safety = struct(...
    'min_following_time', 1.5, ...    % Minimum following time (seconds)
    'min_distance', 10, ...           % Minimum following distance (meters)
    'max_acceleration', 2.5, ...      % Maximum acceleration (m/s^2)
    'max_deceleration', -4.0, ...     % Maximum deceleration (m/s^2)
    'warning_threshold', 0.7, ...     % Warning threshold
    'critical_threshold', 0.9, ...    % Critical threshold
    'warning_timeout', 5.0, ...       % Warning timeout period (seconds)
    'collision_warning_distance', 49.9, ... % Distance for collision warning (meters)
    'min_safe_distance', 20.0, ...    % Minimum safe following distance (meters)
    'max_platoon_length', 100.0 ...   % Maximum platoon length (meters)
    );

% Simulation configuration
config.simulation = struct(...
    'time_step', 0.1, ...              % Simulation time step (seconds)
    'duration', 3600, ...              % Simulation duration (seconds)
    'random_seed', 42, ...             % Random seed for reproducibility
    'frame_rate', 30, ...              % Frame rate for visualization
    'distance_goal', 1609.34, ...      % Distance goal in meters (1 mile)
    'num_random_simulations', 100 ...   % Number of random simulations
    );

% Training configuration
config.training = struct(...
    'batch_size', 32, ...              % Training batch size
    'learning_rate', 0.001, ...        % Learning rate
    'max_epochs', 100, ...             % Maximum training epochs
    'validation_split', 0.2, ...       % Validation split ratio
    'early_stopping', true, ...        % Enable early stopping
    'lstm_hidden_units', 64, ...       % Number of LSTM hidden units
    'mini_batch_size', 16, ...         % Mini batch size for training
    'dropout_rate', 0.2, ...           % Dropout rate for training
    'train_split_ratio', 0.8 ...       % Training data split ratio
    );

% Truck configuration
config.truck = struct(...
    'length', 16.5, ...               % Truck length (meters)
    'width', 2.5, ...                % Truck width (meters)
    'mass', 40000, ...               % Truck mass (kg)
    'max_speed', 25, ...             % Maximum speed (m/s)
    'min_speed', 0, ...              % Minimum speed (m/s)
    'engine_lag', 0.5, ...           % Engine response lag (seconds)
    'num_trucks', 4, ...             % Default number of trucks in platoon
    'min_length', 12.0, ...          % Minimum truck length (meters)
    'max_length', 24.9, ...          % Maximum truck length (meters)
    'min_weight', 10000, ...         % Minimum truck weight (kg)
    'max_weight', 39999, ...         % Maximum truck weight (kg)
    'min_safe_distance', 20.0, ...   % Minimum safe distance between trucks (meters)
    'max_velocity', 30.0, ...        % Maximum velocity (m/s)
    'max_acceleration', 2.0, ...     % Maximum acceleration (m/s^2)
    'max_deceleration', -3.0, ...    % Maximum deceleration (m/s^2)
    'initial_spacing', 25.0 ...      % Initial spacing between trucks (meters)
    );

% Visualization configuration
config.visualization = struct(...
    'enabled', true, ...              % Enable visualization
    'update_rate', 10, ...            % Update rate (Hz)
    'show_safety_indicators', true, ... % Show safety indicators
    'plot_style', 'dark' ...          % Plot style ('light' or 'dark')
    );

% Create required directories
dirs = {...
    config.paths.data_dir, ...
    config.paths.model_dir, ...
    config.paths.log_dir ...
    };

for i = 1:length(dirs)
    if ~exist(dirs{i}, 'dir')
        [success, msg] = mkdir(dirs{i});
        if ~success
            warning('Failed to create directory %s: %s', dirs{i}, msg);
        end
    end
end
end