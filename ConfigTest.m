classdef ConfigTest < matlab.unittest.TestCase
    % CONFIGTEST Dedicated test suite for configuration validation
    %
    % Tests the configuration system including:
    % - Configuration structure completeness
    % - Type validation
    % - Value range validation
    % - Default values
    % - Configuration immutability
    % - Multiple call consistency
    %
    % Author: zplotzke
    % Last Modified: 2025-02-15 03:14:52 UTC
    % Version: 1.0.4

    properties
        config  % Main configuration structure
        defaultConfig  % Reference configuration for comparison
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            % Get fresh configuration for each test
            testCase.config = config.getConfig();
            testCase.defaultConfig = config.getConfig();
        end
    end

    methods (Test)
        function testConfigurationStructure(testCase)
            % Test main structure fields
            expectedFields = sort({...
                'simulation', ...
                'truck', ...
                'safety', ...
                'training', ...
                'visualization', ...
                'paths', ...
                'logging'});

            actualFields = sort(fieldnames(testCase.config));
            testCase.verifyEqual(actualFields(:)', expectedFields(:)', ...
                'Configuration missing required top-level sections');
        end

        function testSimulationSection(testCase)
            % Test simulation section fields and types
            expectedFields = sort({...
                'duration', ...
                'time_step', ...
                'distance_goal', ...
                'num_random_simulations', ...
                'frame_rate', ...
                'random_seed'});

            actualFields = sort(fieldnames(testCase.config.simulation));
            testCase.verifyEqual(actualFields(:)', expectedFields(:)', ...
                'Simulation section missing required fields');

            % Type checking
            testCase.verifyClass(testCase.config.simulation.duration, 'double');
            testCase.verifyClass(testCase.config.simulation.time_step, 'double');
            testCase.verifyClass(testCase.config.simulation.random_seed, 'double');
        end

        function testSimulationRanges(testCase)
            % Test simulation parameter ranges
            sim = testCase.config.simulation;

            % Time parameters must be positive
            testCase.verifyGreaterThan(sim.time_step, 0, ...
                'Time step must be positive');
            testCase.verifyLessThan(sim.time_step, 1.0, ...
                'Time step must be less than 1.0 seconds');

            testCase.verifyGreaterThan(sim.duration, 0, ...
                'Simulation duration must be positive');
            testCase.verifyLessThan(sim.duration, 86400, ...
                'Simulation duration must be less than 24 hours');

            % Frame rate must be between reasonable bounds (1-240 fps)
            testCase.verifyGreaterThanOrEqual(sim.frame_rate, 1, ...
                'Frame rate must be at least 1 fps');
            testCase.verifyLessThanOrEqual(sim.frame_rate, 240, ...
                'Frame rate must be at most 240 fps');

            % Number of simulations must be positive integer
            testCase.verifyTrue(mod(sim.num_random_simulations, 1) == 0, ...
                'Number of random simulations must be an integer');
            testCase.verifyGreaterThan(sim.num_random_simulations, 0, ...
                'Number of random simulations must be positive');

            % Distance goal must be positive (one mile in meters)
            testCase.verifyGreaterThan(sim.distance_goal, 0, ...
                'Distance goal must be positive');
            testCase.verifyEqual(sim.distance_goal, 1609.34, 'AbsTol', 1e-2, ...
                'Distance goal should be one mile in meters');
        end

        function testTruckRanges(testCase)
            % Test truck parameter ranges
            truck = testCase.config.truck;

            % Number of trucks must be integer between 2 and 10
            testCase.verifyTrue(mod(truck.num_trucks, 1) == 0, ...
                'Number of trucks must be an integer');
            testCase.verifyGreaterThanOrEqual(truck.num_trucks, 2, ...
                'Must have at least 2 trucks');
            testCase.verifyLessThanOrEqual(truck.num_trucks, 10, ...
                'Cannot have more than 10 trucks');

            % Physical dimensions
            testCase.verifyGreaterThan(truck.min_length, 10, ...
                'Minimum truck length must be greater than 10m');
            testCase.verifyLessThan(truck.min_length, 25, ...
                'Minimum truck length must be less than 25m');

            testCase.verifyGreaterThan(truck.max_length, truck.min_length, ...
                'Maximum length must be greater than minimum length');
            testCase.verifyLessThan(truck.max_length, 25, ...
                'Maximum length must be less than 25m');

            % Weight ranges
            testCase.verifyGreaterThan(truck.min_weight, 5000, ...
                'Minimum weight must be greater than 5000kg');
            testCase.verifyLessThan(truck.min_weight, truck.max_weight, ...
                'Minimum weight must be less than maximum weight');

            testCase.verifyGreaterThan(truck.max_weight, truck.min_weight, ...
                'Maximum weight must be greater than minimum weight');
            testCase.verifyLessThan(truck.max_weight, 40000, ...
                'Maximum weight must be less than 40000kg');

            % Speed and acceleration limits
            testCase.verifyGreaterThan(truck.max_velocity, 0, ...
                'Maximum velocity must be positive');
            testCase.verifyLessThan(truck.max_velocity, 40, ...
                'Maximum velocity must be less than 40 m/s (~144 km/h)');

            testCase.verifyGreaterThan(truck.max_acceleration, 0, ...
                'Maximum acceleration must be positive');
            testCase.verifyLessThan(truck.max_acceleration, 5, ...
                'Maximum acceleration must be less than 5 m/s²');

            testCase.verifyLessThan(truck.max_deceleration, 0, ...
                'Maximum deceleration must be negative');
            testCase.verifyGreaterThan(truck.max_deceleration, -10, ...
                'Maximum deceleration must be greater than -10 m/s²');

            % Spacing
            testCase.verifyGreaterThan(truck.initial_spacing, truck.min_safe_distance, ...
                'Initial spacing must be greater than minimum safe distance');
            testCase.verifyLessThan(truck.initial_spacing, 100, ...
                'Initial spacing must be less than 100m');
        end

        function testSafetyRanges(testCase)
            % Test safety parameter ranges
            safety = testCase.config.safety;

            testCase.verifyGreaterThan(safety.min_following_time, 1.0, ...
                'Minimum following time must be greater than 1.0 seconds');
            testCase.verifyLessThan(safety.min_following_time, 5.0, ...
                'Minimum following time must be less than 5.0 seconds');

            testCase.verifyGreaterThan(safety.warning_timeout, 0, ...
                'Warning timeout must be positive');
            testCase.verifyLessThan(safety.warning_timeout, 10.0, ...
                'Warning timeout must be less than 10.0 seconds');

            testCase.verifyGreaterThan(safety.collision_warning_distance, ...
                testCase.config.truck.min_safe_distance, ...
                'Collision warning distance must be greater than minimum safe distance');
            testCase.verifyLessThan(safety.collision_warning_distance, 50, ...
                'Collision warning distance must be less than 50m');

            testCase.verifyGreaterThan(safety.max_platoon_length, 50, ...
                'Maximum platoon length must be greater than 50m');
            testCase.verifyLessThan(safety.max_platoon_length, 500, ...
                'Maximum platoon length must be less than 500m');
        end

        function testTrainingRanges(testCase)
            % Test training parameter ranges
            training = testCase.config.training;

            % Network parameters
            testCase.verifyTrue(mod(training.lstm_hidden_units, 1) == 0, ...
                'LSTM hidden units must be an integer');
            testCase.verifyGreaterThan(training.lstm_hidden_units, 10, ...
                'LSTM hidden units must be greater than 10');
            testCase.verifyLessThan(training.lstm_hidden_units, 1000, ...
                'LSTM hidden units must be less than 1000');

            % Training parameters
            testCase.verifyTrue(mod(training.max_epochs, 1) == 0, ...
                'Max epochs must be an integer');
            testCase.verifyGreaterThan(training.max_epochs, 1, ...
                'Max epochs must be greater than 1');
            testCase.verifyLessThan(training.max_epochs, 1000, ...
                'Max epochs must be less than 1000');

            testCase.verifyTrue(mod(training.mini_batch_size, 1) == 0, ...
                'Mini batch size must be an integer');
            testCase.verifyGreaterThan(training.mini_batch_size, 1, ...
                'Mini batch size must be greater than 1');
            testCase.verifyLessThan(training.mini_batch_size, 1024, ...
                'Mini batch size must be less than 1024');

            % Learning parameters
            testCase.verifyGreaterThan(training.learning_rate, 0, ...
                'Learning rate must be positive');
            testCase.verifyLessThan(training.learning_rate, 1, ...
                'Learning rate must be less than 1');

            testCase.verifyGreaterThan(training.dropout_rate, 0, ...
                'Dropout rate must be positive');
            testCase.verifyLessThan(training.dropout_rate, 1, ...
                'Dropout rate must be less than 1');

            testCase.verifyGreaterThan(training.train_split_ratio, 0.5, ...
                'Training split ratio must be greater than 0.5');
            testCase.verifyLessThan(training.train_split_ratio, 0.9, ...
                'Training split ratio must be less than 0.9');
        end

        function testLoggingConfiguration(testCase)
            % Test logging configuration
            logging = testCase.config.logging;

            % Valid log levels
            validLevels = {'DEBUG', 'INFO', 'WARNING', 'ERROR'};
            testCase.verifyTrue(ismember(upper(logging.log_level), validLevels), ...
                'Log level must be one of: DEBUG, INFO, WARNING, ERROR');

            % Boolean flags
            testCase.verifyTrue(islogical(logging.file_logging), ...
                'file_logging must be logical');
            testCase.verifyTrue(islogical(logging.console_logging), ...
                'console_logging must be logical');
        end

        function testConsistency(testCase)
            % Test that multiple calls return consistent values
            config1 = config.getConfig();
            config2 = config.getConfig();
            testCase.verifyEqual(config1, config2, ...
                'Multiple getConfig calls returned different values');
        end

        function testImmutability(testCase)
            % Test that configuration is immutable
            original = testCase.config.simulation.time_step;
            testCase.config.simulation.time_step = 999;
            newConfig = config.getConfig();
            testCase.verifyEqual(newConfig.simulation.time_step, original, ...
                'Configuration values should not be modifiable');
        end

        function testDefaultValues(testCase)
            % Test default values for critical parameters
            testCase.verifyEqual(testCase.config.simulation.time_step, 0.1, ...
                'Incorrect default time step');
            testCase.verifyEqual(testCase.config.simulation.duration, 3600, ...
                'Incorrect default simulation duration');
            testCase.verifyEqual(testCase.config.truck.num_trucks, 4, ...
                'Incorrect default number of trucks');
            testCase.verifyEqual(testCase.config.simulation.random_seed, 42, ...
                'Incorrect default random seed');
        end
    end
end