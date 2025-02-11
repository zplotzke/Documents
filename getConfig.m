function config = getConfig()
% GETCONFIG Returns core configuration structure for truck platoon simulation
%
% Returns:
%   config - Structure containing core simulation parameters
%
% Version History:
%   v1.0.6 (2025-02-11) - Removed visualization config (stays in visualizePlatoon)
%   v1.0.5 (2025-02-11) - Added configuration backup and enhanced safety parameters
%   v1.0.4 (2025-02-11) - Added enhanced visualization parameters
%   v1.0.3 (2025-02-08) - Added configurable truck lengths
%   v1.0.2 (2025-02-08) - Added weight constants
%   v1.0.1 (2025-02-08) - Added fixed truck weights configuration
%   v1.0.0 (2025-02-08) - Initial version
%
% Author: zplotzke
% Last Modified: 2025-02-11 03:10:58 UTC

% Constants for truck specifications (based on standard EU regulations)
TRUCK_SPECS = struct(...
    'MIN_WEIGHT', 15000, ... % Minimum allowed truck weight (kg) - empty truck
    'MAX_WEIGHT', 40000, ... % Maximum allowed truck weight (kg) - fully loaded
    'MIN_LENGTH', 12.0, ...  % Minimum allowed truck length (m) - rigid truck
    'MAX_LENGTH', 25.0, ...  % Maximum allowed truck length (m) - articulated vehicle
    'NUM_TRUCKS', 4, ...     % Number of trucks in platoon
    'WEIGHT_TOLERANCE', 500, ... % Weight measurement tolerance (kg)
    'LENGTH_TOLERANCE', 0.1);    % Length measurement tolerance (m)

% Version control
config.version = '1.0.6';
config.last_modified = '2025-02-11 03:10:58';  % Current UTC time
config.last_modified_by = 'zplotzke';          % Current user

% Initialize paths
config.paths = struct(...
    'base_dir', pwd(), ...
    'data_dir', fullfile(pwd(), 'data'), ...
    'log_dir', fullfile(pwd(), 'logs'), ...
    'results_dir', fullfile(pwd(), 'results'), ...
    'config_backup', fullfile(pwd(), 'config_backups'));

% Create required directories
dirs = fieldnames(config.paths);
for i = 1:length(dirs)
    if ~strcmp(dirs{i}, 'base_dir')
        if ~exist(config.paths.(dirs{i}), 'dir')
            mkdir(config.paths.(dirs{i}));
        end
    end
end

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
    'weight_tolerance', TRUCK_SPECS.WEIGHT_TOLERANCE, ... % Weight tolerance (kg)
    'length_tolerance', TRUCK_SPECS.LENGTH_TOLERANCE, ... % Length tolerance (m)
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

% Create collision thresholds struct first
collision_thresholds = struct(...
    'critical', 0.8, ...           % Critical threshold (80% of min safe distance)
    'warning', 1.2, ...            % Warning threshold (120% of min safe distance)
    'alert', 1.5);                 % Alert threshold (150% of min safe distance)

% Safety parameters
config.safety = struct(...
    'min_safe_distance', 10.0, ...  % Minimum safe distance between trucks (m)
    'max_acceleration', 2.0, ...    % Maximum acceleration (m/s^2)
    'max_deceleration', -6.0, ...   % Maximum deceleration (m/s^2)
    'max_jerk', 1.0, ...            % Maximum jerk (m/s^3)
    'emergency_brake_decel', -7.5, ... % Emergency braking deceleration (m/s^2)
    'reaction_time', 0.3, ...        % System reaction time (s)
    'warning_frequencies', [...      % Warning frequencies (Hz)
    2.0;    % Distance warning frequency
    1.0;    % Velocity warning frequency
    1.5;    % Acceleration warning frequency
    0.5     % Jerk warning frequency
    ], ...
    'collision_thresholds', collision_thresholds);

% Simulation parameters
config.simulation = struct(...
    'frame_rate', 30, ...           % Simulation frame rate (Hz)
    'final_time', 300, ...          % Simulation duration (s)
    'num_random_simulations', 10);  % Number of random simulations for training

end