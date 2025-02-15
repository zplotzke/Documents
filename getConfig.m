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
% Last Modified: 2025-02-15 05:04:48 UTC
% Version: 1.0.3

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
    'max_velocity', 33.33, ...              % Maximum velocity (120 km/h in m/s)
    'initial_velocity', 0, ...              % Initial velocity (m/s)
    'constant_acceleration', 0 ...           % Constant acceleration if needed (m/s^2)
    );

% Safety thresholds
config.safety = struct(...
    'min_following_time', 1.5, ...           % Minimum time gap (seconds)
    'emergency_decel_threshold', -4.0, ...   % Emergency deceleration threshold (m/s^2)
    'collision_warning_distance', 15.0, ...  % Distance for collision warning (meters)
    'max_platoon_length', 100.0, ...        % Maximum total platoon length (meters)
    'warning_timeout', 5.0, ...             % Minimum time between warnings (seconds)
    'max_lateral_deviation', 0.3, ...       % Maximum lateral deviation (meters)
    'min_brake_pressure', 0.2, ...         % Minimum brake pressure for emergency (bar)
    'reaction_time_threshold', 0.5 ...      % Critical reaction time threshold (seconds)
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
    'window_size', [1280, 720], ...         % Window size for visualization [width, height]
    'truck_colors', {{'b', 'r', 'g', 'y'}}, ... % Colors for each truck
    'plot_refresh_rate', 5, ...             % Plot refresh rate in Hz
    'show_predictions', true, ...           % Enable/disable prediction visualization
    'show_safety_zones', true, ...         % Enable/disable safety zone visualization
    'plot_history_length', 1000, ...       % Number of points to keep in history plots
    'road_width', 10, ...                  % Width of the road in meters
    'truck_width', 2.5, ...                % Width of truck visualization in meters
    'margin_factor', 1.5, ...              % View margin factor for visualization
    'min_view_width', 300 ...              % Minimum view width in meters
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
    'log_format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s' ... % Log format string
    );

% Add debug flags
if isdeployed
    config.debug = struct(...
        'enable_assertions', false, ...      % Disable assertions in deployed code
        'verbose_logging', false, ...        % Disable verbose logging in deployed code
        'profile_performance', false ...     % Disable performance profiling in deployed code
        );
else
    config.debug = struct(...
        'enable_assertions', true, ...       % Enable assertions during development
        'verbose_logging', true, ...         % Enable verbose logging during development
        'profile_performance', true ...      % Enable performance profiling during development
        );
end

% Add system-specific overrides
try
    % Check for system-specific configuration file
    if exist('local_config.m', 'file')
        local_overrides = local_config();
        config = mergeConfigs(config, local_overrides);
    end
catch ME
    warning('Failed to load local configuration: %s', ME.message);
end

end

function merged = mergeConfigs(base, override)
% Helper function to merge configuration structures
merged = base;
fields = fieldnames(override);
for i = 1:length(fields)
    field = fields{i};
    if isfield(base, field) && isstruct(base.(field)) && isstruct(override.(field))
        merged.(field) = mergeConfigs(base.(field), override.(field));
    else
        merged.(field) = override.(field);
    end
end
end