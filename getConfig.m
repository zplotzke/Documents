function config = getConfig()
% GETCONFIG Configuration settings for truck platoon simulation
%
% Returns a structure containing all configuration parameters for:
% - Simulation parameters
% - Truck specifications
% - Safety thresholds
% - LSTM network configuration
% - Visualization settings
%
% Author: zplotzke
% Last Modified: 2025-02-12 17:49:13 UTC
% Version: 1.0.1

% Initialize configuration structure
config = struct();

% Simulation parameters
config.simulation = struct(...
    'duration', 3600, ...                    % Maximum simulation duration (seconds)
    'time_step', 0.1, ...                    % Simulation time step (seconds)
    'distance_goal', 1609.34, ...            % One mile in meters
    'num_random_simulations', 10, ...        % Number of training simulations
    'frame_rate', 30, ...                    % Visualization frame rate (fps)
    'random_seed', 42 ...                    % Random seed for reproducibility
    );

% Truck specifications
config.truck = struct(...
    'num_trucks', 4, ...                     % Number of trucks in platoon
    'min_length', 16.15, ...                 % Minimum truck length (meters)
    'max_length', 18.75, ...                 % Maximum truck length (meters)
    'min_weight', 15000, ...                 % Minimum truck weight (kg)
    'max_weight', 36000, ...                 % Maximum truck weight (kg)
    'max_acceleration', 2.5, ...             % Maximum acceleration (m/s^2)
    'max_deceleration', -6.0, ...           % Maximum deceleration (m/s^2)
    'max_jerk', 2.0, ...                    % Maximum jerk (m/s^3)
    'initial_spacing', 20.0, ...            % Initial spacing between trucks (meters)
    'min_safe_distance', 10.0, ...          % Minimum safe following distance (meters)
    'max_velocity', 33.33 ...               % Maximum velocity (120 km/h in m/s)
    );

% Safety thresholds
config.safety = struct(...
    'min_following_time', 1.5, ...           % Minimum time gap (seconds)
    'emergency_decel_threshold', -4.0, ...   % Emergency deceleration threshold (m/s^2)
    'collision_warning_distance', 15.0, ...  % Distance for collision warning (meters)
    'max_platoon_length', 100.0, ...        % Maximum total platoon length (meters)
    'warning_timeout', 5.0 ...              % Minimum time between warnings (seconds)
    );

% LSTM Network configuration
config.training = struct(...
    'lstm_hidden_units', 100, ...            % Number of hidden units in LSTM layer
    'max_epochs', 100, ...                   % Maximum training epochs
    'mini_batch_size', 32, ...              % Mini-batch size for training
    'learning_rate', 0.001, ...             % Initial learning rate
    'gradient_threshold', 1, ...            % Gradient clipping threshold
    'validation_split', 0.2, ...            % Fraction of data for validation
    'sequence_length', 50, ...              % Sequence length for LSTM training
    'train_split_ratio', 0.8, ...           % Training data split ratio (80% training, 20% validation)
    'dropout_rate', 0.2 ...                 % Dropout rate for regularization
    );

% Add visualization-specific parameters
config.visualization = struct(...
    'window_size', [1280, 720], ...
    'truck_colors', {{'b', 'r', 'g', 'y'}}, ...
    'plot_refresh_rate', 5, ...
    'show_predictions', true, ...
    'show_safety_zones', true, ...
    'plot_history_length', 1000, ...
    'road_width', 10, ...           % Added
    'truck_width', 2.5, ...         % Added
    'margin_factor', 1.5, ...       % Added
    'min_view_width', 300 ...       % Added
    );

% File paths and logging
config.paths = struct(...
    'data_dir', 'data', ...                 % Directory for saving simulation data
    'log_dir', 'logs', ...                  % Directory for log files
    'models_dir', 'models', ...             % Directory for saved models
    'results_dir', 'results' ...            % Directory for simulation results
    );

% Logging configuration
config.logging = struct(...
    'log_level', 'INFO', ...                % Default logging level
    'file_logging', true, ...               % Enable logging to file
    'console_logging', true, ...            % Enable console logging
    'log_format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s' ... % Log format
    );

end