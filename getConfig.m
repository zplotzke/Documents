function config = getConfig()
% GETCONFIG Returns configuration structure for truck platoon simulation
%
% Returns:
%   config - Structure containing all configuration parameters with validation
%
% Version History:
%   v1.0.3 (2025-02-08) - Added configurable truck lengths
%   v1.0.2 (2025-02-08) - Added weight constants and validation
%   v1.0.1 (2025-02-08) - Added fixed truck weights configuration
%   v1.0.0 (2025-02-08) - Initial version with parameter validation
%
% Author: zplotzke
% Last Modified: 2025-02-08 16:46:09 UTC

% Constants for truck specifications
TRUCK_SPECS = struct(...
    'MIN_WEIGHT', 15000, ... % Minimum allowed truck weight (kg)
    'MAX_WEIGHT', 40000, ... % Maximum allowed truck weight (kg)
    'MIN_LENGTH', 12.0, ...  % Minimum allowed truck length (m)
    'MAX_LENGTH', 25.0, ...  % Maximum allowed truck length (m)
    'NUM_TRUCKS', 4);        % Number of trucks in platoon

% Version control
config.version = '1.0.3';
config.last_modified = '2025-02-08 16:46:09';

% Truck configuration
config.truck = struct(...
    'num_trucks', TRUCK_SPECS.NUM_TRUCKS, ...  % Number of trucks in platoon
    'min_length', TRUCK_SPECS.MIN_LENGTH, ...  % Minimum allowed length (m)
    'max_length', TRUCK_SPECS.MAX_LENGTH, ...  % Maximum allowed length (m)
    'initial_speed', 22.22, ...                % Initial speed (m/s) [80 km/h]
    'desired_gap', 20.0, ...                   % Desired gap between trucks (m)
    'max_relative_velocity', 5.0, ...          % Maximum relative velocity (m/s)
    'min_weight', TRUCK_SPECS.MIN_WEIGHT, ...  % Minimum allowed weight (kg)
    'max_weight', TRUCK_SPECS.MAX_WEIGHT, ...  % Maximum allowed weight (kg)
    'truck_weights', [...                      % Weight of each truck (kg)
    35000;  % Truck 1: Standard loaded semi-truck
    32000;  % Truck 2: Lighter loaded semi-truck
    38000;  % Truck 3: Heavily loaded semi-truck
    30000   % Truck 4: Lightly loaded semi-truck
    ], ...
    'truck_lengths', [...                      % Length of each truck (m)
    16.5;   % Truck 1: Standard semi-truck
    14.5;   % Truck 2: Shorter semi-truck
    18.0;   % Truck 3: Extended semi-truck
    15.5    % Truck 4: Standard semi-truck
    ]);

% Verify weights are within specifications
assert(all(config.truck.truck_weights >= TRUCK_SPECS.MIN_WEIGHT) && ...
    all(config.truck.truck_weights <= TRUCK_SPECS.MAX_WEIGHT), ...
    'Initial truck weights must be between %d kg and %d kg', ...
    TRUCK_SPECS.MIN_WEIGHT, TRUCK_SPECS.MAX_WEIGHT);

% Verify lengths are within specifications
assert(all(config.truck.truck_lengths >= TRUCK_SPECS.MIN_LENGTH) && ...
    all(config.truck.truck_lengths <= TRUCK_SPECS.MAX_LENGTH), ...
    'Initial truck lengths must be between %.1f m and %.1f m', ...
    TRUCK_SPECS.MIN_LENGTH, TRUCK_SPECS.MAX_LENGTH);

% Safety parameters
config.safety = struct(...
    'min_safe_distance', 10.0, ...  % Minimum safe distance between trucks (m)
    'max_acceleration', 2.0, ...    % Maximum acceleration (m/s^2)
    'max_deceleration', -6.0, ...   % Maximum deceleration (m/s^2)
    'max_jerk', 1.0, ...            % Maximum jerk (m/s^3)
    'warning_frequencies', [...     % Warning frequencies (Hz)
    2.0;    % Distance warning frequency
    1.0;    % Velocity warning frequency
    1.5;    % Acceleration warning frequency
    0.5     % Jerk warning frequency
    ]);

% Simulation parameters
config.simulation = struct(...
    'frame_rate', 10, ...          % Simulation frame rate (Hz)
    'final_time', 60, ...          % Simulation duration (s)
    'num_random_simulations', 10); % Number of random simulations for training

% Initialize paths
config.paths = initializePaths();

% Validate configuration
validateConfig(config);
end

function paths = initializePaths()
% Generate paths structure with default values
paths = struct();

% Get current directory as base
paths.base_dir = pwd();

% Create timestamp for unique folders
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');

% Define subdirectories
paths.data_dir = fullfile(paths.base_dir, 'data');
paths.log_dir = fullfile(paths.base_dir, 'logs');
paths.results_dir = fullfile(paths.base_dir, 'results', timestamp);

% Create directories if they don't exist
createDirectoryIfNeeded(paths.data_dir);
createDirectoryIfNeeded(paths.log_dir);
createDirectoryIfNeeded(paths.results_dir);
end

function createDirectoryIfNeeded(dir_path)
if ~exist(dir_path, 'dir')
    [success, msg] = mkdir(dir_path);
    if ~success
        warning('Failed to create directory %s: %s', dir_path, msg);
    end
end
end

function validateConfig(config)
% Constants for validation
MIN_TRUCK_WEIGHT = 15000;  % Minimum allowed truck weight in kg
MAX_TRUCK_WEIGHT = 40000;  % Maximum allowed truck weight in kg
MIN_TRUCK_LENGTH = 12.0;   % Minimum allowed truck length in m
MAX_TRUCK_LENGTH = 25.0;   % Maximum allowed truck length in m

% Validate truck configuration
validateattributes(config.truck.num_trucks, {'numeric'}, ...
    {'scalar', 'positive', 'integer'}, 'getConfig', 'num_trucks');

% Validate weights
validateattributes(config.truck.truck_weights, {'numeric'}, ...
    {'vector', 'positive', 'numel', config.truck.num_trucks}, ...
    'getConfig', 'truck_weights');

% Validate lengths
validateattributes(config.truck.truck_lengths, {'numeric'}, ...
    {'vector', 'positive', 'numel', config.truck.num_trucks}, ...
    'getConfig', 'truck_lengths');

% Check weight ranges
invalid_weights = config.truck.truck_weights < MIN_TRUCK_WEIGHT | ...
    config.truck.truck_weights > MAX_TRUCK_WEIGHT;

if any(invalid_weights)
    invalid_indices = find(invalid_weights);
    error('Trucks:InvalidWeights', ...
        'Truck weights must be between %d kg and %d kg. Invalid weights at positions: %s', ...
        MIN_TRUCK_WEIGHT, MAX_TRUCK_WEIGHT, mat2str(invalid_indices));
end

% Check length ranges
invalid_lengths = config.truck.truck_lengths < MIN_TRUCK_LENGTH | ...
    config.truck.truck_lengths > MAX_TRUCK_LENGTH;

if any(invalid_lengths)
    invalid_indices = find(invalid_lengths);
    error('Trucks:InvalidLengths', ...
        'Truck lengths must be between %.1f m and %.1f m. Invalid lengths at positions: %s', ...
        MIN_TRUCK_LENGTH, MAX_TRUCK_LENGTH, mat2str(invalid_indices));
end

% Validate safety parameters
validateattributes(config.safety.min_safe_distance, {'numeric'}, ...
    {'scalar', 'positive'}, 'getConfig', 'min_safe_distance');

validateattributes(config.safety.warning_frequencies, {'numeric'}, ...
    {'vector', 'positive'}, 'getConfig', 'warning_frequencies');

% Validate simulation parameters
validateattributes(config.simulation.frame_rate, {'numeric'}, ...
    {'scalar', 'positive'}, 'getConfig', 'frame_rate');

validateattributes(config.simulation.final_time, {'numeric'}, ...
    {'scalar', 'positive'}, 'getConfig', 'final_time');
end