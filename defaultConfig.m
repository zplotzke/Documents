function config = defaultConfig()
% DEFAULTCONFIG Default configuration for the truck platoon system
%
% Author: zplotzke
% Last Modified: 2025-02-19 17:59:44 UTC
% Version: 1.4.1

config = struct();

% Truck configuration
config.truck = struct();
config.truck.num_trucks = 4;
config.truck.min_safe_distance = 10;  % meters
config.truck.max_safe_distance = 50;  % meters
config.truck.initial_spacing = 20;    % meters
config.truck.max_acceleration = 2.5;  % m/s^2
config.truck.max_deceleration = -4.0; % m/s^2
config.truck.length = 16.5;          % meters (standard 18-wheeler)

% Training configuration
config.trainer = struct();  % Using 'trainer' consistently
config.trainer.learning_rate = 0.001;
config.trainer.batch_size = 32;
config.trainer.epochs = 100;
config.trainer.validation_split = 0.2;
config.trainer.optimizer = 'adam';
config.trainer.loss_function = 'mse';
config.trainer.early_stopping_patience = 10;
config.trainer.min_delta = 1e-4;
config.trainer.shuffle = true;
config.trainer.verbose = true;

% Warning system configuration
config.warning = struct();
config.warning.timeout = 5.0;        % seconds
config.warning.min_interval = 1.0;   % seconds
config.warning.max_warnings = 3;     % per event

% Sonification configuration
config.sound = struct();
config.sound.sample_rate = 44100;    % Hz
config.sound.duration = 0.5;         % seconds
config.sound.fade_duration = 0.05;   % seconds

% Safety monitor configuration
config.safety = struct();
config.safety.update_rate = 10;      % Hz
config.safety.reaction_time = 0.5;   % seconds
config.safety.warning_threshold = 0.7;% fraction of safe distance

end