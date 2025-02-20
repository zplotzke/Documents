classdef ConfigTest < matlab.unittest.TestCase
    % CONFIGTEST Test case for configuration validation
    %
    % Tests all sections of the configuration file to ensure:
    % - All required fields are present
    % - Fields have correct data types
    % - Values are within expected ranges
    % - Structures are properly nested
    %
    % Author: zplotzke
    % Last Modified: 2025-02-19 20:15:58 UTC
    % Version: 1.1.3

    properties
        config
    end

    methods(TestMethodSetup)
        function setupConfig(testCase)
            % Use the fully qualified package name
            testCase.config = config.getConfig();
        end
    end

    methods(Test)
        function testNetworkSection(testCase)
            % Test that network section has all required fields
            network = testCase.config.network;

            expected_fields = {...
                'activation_function', ...
                'dropout_rate', ...
                'gradient_clip', ...
                'hidden_size', ...
                'input_size', ...
                'learning_rate', ...
                'max_epochs', ...
                'mini_batch_size', ...
                'optimizer', ...
                'output_size', ...
                'sequence_length', ...
                'weight_decay' ...
                };

            actual_fields = sort(fieldnames(network))';
            testCase.verifyEqual(actual_fields, expected_fields, ...
                'Network section missing required fields');

            % Verify field types
            testCase.verifyClass(network.input_size, 'double');
            testCase.verifyClass(network.hidden_size, 'double');
            testCase.verifyClass(network.output_size, 'double');
            testCase.verifyClass(network.learning_rate, 'double');
            testCase.verifyClass(network.max_epochs, 'double');
            testCase.verifyClass(network.mini_batch_size, 'double');
            testCase.verifyClass(network.dropout_rate, 'double');
            testCase.verifyClass(network.activation_function, 'char');
            testCase.verifyClass(network.optimizer, 'char');
            testCase.verifyClass(network.weight_decay, 'double');
            testCase.verifyClass(network.gradient_clip, 'double');
            testCase.verifyClass(network.sequence_length, 'double');

            % Verify value ranges
            testCase.verifyGreaterThan(network.input_size, 0);
            testCase.verifyGreaterThan(network.hidden_size, 0);
            testCase.verifyGreaterThan(network.output_size, 0);
            testCase.verifyGreaterThan(network.learning_rate, 0);
            testCase.verifyGreaterThan(network.max_epochs, 0);
            testCase.verifyGreaterThan(network.mini_batch_size, 0);
            testCase.verifyGreaterThan(network.sequence_length, 0);

            % Verify dropout rate is between 0 and 1
            testCase.verifyGreaterThanOrEqual(network.dropout_rate, 0);
            testCase.verifyLessThan(network.dropout_rate, 1);
        end

        function testTrainerSection(testCase)
            % Test that trainer section has all required fields
            trainer = testCase.config.trainer;

            expected_fields = {...
                'batch_size', ...
                'checkpoint_dir', ...
                'early_stopping_patience', ...
                'epochs', ...
                'learning_rate', ...
                'loss_function', ...
                'max_queue_size', ...
                'min_delta', ...
                'optimizer', ...
                'save_best_only', ...
                'shuffle', ...
                'validation_split', ...
                'verbose', ...
                'workers' ...
                };

            actual_fields = sort(fieldnames(trainer))';
            testCase.verifyEqual(actual_fields, expected_fields, ...
                'Trainer section missing required fields');

            % Verify field types
            testCase.verifyClass(trainer.batch_size, 'double');
            testCase.verifyClass(trainer.epochs, 'double');
            testCase.verifyClass(trainer.validation_split, 'double');
            testCase.verifyClass(trainer.learning_rate, 'double');
            testCase.verifyClass(trainer.optimizer, 'char');
            testCase.verifyClass(trainer.loss_function, 'char');
            testCase.verifyClass(trainer.early_stopping_patience, 'double');
            testCase.verifyClass(trainer.min_delta, 'double');
            testCase.verifyClass(trainer.shuffle, 'logical');
            testCase.verifyClass(trainer.verbose, 'logical');
            testCase.verifyClass(trainer.checkpoint_dir, 'char');
            testCase.verifyClass(trainer.save_best_only, 'logical');
            testCase.verifyClass(trainer.max_queue_size, 'double');
            testCase.verifyClass(trainer.workers, 'double');

            % Verify value ranges
            testCase.verifyGreaterThan(trainer.batch_size, 0);
            testCase.verifyGreaterThan(trainer.epochs, 0);
            testCase.verifyGreaterThan(trainer.learning_rate, 0);
            testCase.verifyGreaterThan(trainer.early_stopping_patience, 0);
            testCase.verifyGreaterThan(trainer.min_delta, 0);

            % Verify validation split is between 0 and 1
            testCase.verifyGreaterThan(trainer.validation_split, 0);
            testCase.verifyLessThan(trainer.validation_split, 1);
        end

        function testSafetySection(testCase)
            % Test that safety section has all required fields
            safety = testCase.config.safety;

            expected_fields = {...
                'collision_time_threshold', ...
                'collision_warning_distance', ...
                'emergency_brake_duration', ...
                'emergency_decel_threshold', ...
                'max_lateral_deviation', ...
                'max_platoon_length', ...
                'max_speed_difference', ...
                'min_brake_pressure', ...
                'min_following_time', ...
                'min_safety_distance', ...
                'reaction_time_threshold', ...
                'warning_levels', ...
                'warning_timeout' ...
                };

            actual_fields = sort(fieldnames(safety))';
            testCase.verifyEqual(actual_fields, expected_fields, ...
                'Safety section missing required fields');

            % Verify field types
            testCase.verifyClass(safety.collision_warning_distance, 'double');
            testCase.verifyClass(safety.emergency_decel_threshold, 'double');
            testCase.verifyClass(safety.min_following_time, 'double');
            testCase.verifyClass(safety.max_platoon_length, 'double');
            testCase.verifyClass(safety.warning_timeout, 'double');
            testCase.verifyClass(safety.max_lateral_deviation, 'double');
            testCase.verifyClass(safety.min_brake_pressure, 'double');
            testCase.verifyClass(safety.warning_levels, 'struct');

            % Verify value ranges
            testCase.verifyGreaterThan(safety.collision_warning_distance, 0);
            testCase.verifyLessThan(safety.emergency_decel_threshold, 0);
            testCase.verifyGreaterThan(safety.min_following_time, 0);
            testCase.verifyGreaterThan(safety.max_platoon_length, 0);
            testCase.verifyGreaterThan(safety.warning_timeout, 0);
            testCase.verifyGreaterThan(safety.max_lateral_deviation, 0);
            testCase.verifyGreaterThan(safety.min_brake_pressure, 0);
        end

        function testSimulationSection(testCase)
            % Test that simulation section has all required fields
            simulation = testCase.config.simulation;

            expected_fields = {...
                'fault_injection', ...
                'log_level', ...
                'max_simulation_time', ...
                'metrics', ...
                'num_random_simulations', ...
                'output_directory', ...
                'random_seed', ...
                'save_interval', ...
                'scenario_file', ...
                'time_step', ...
                'traffic_enabled', ...
                'update_frequency', ...
                'visualization_enabled', ...
                'weather_enabled' ...
                };

            actual_fields = sort(fieldnames(simulation))';
            testCase.verifyEqual(actual_fields, expected_fields, ...
                'Simulation section missing required fields');

            % Verify field types
            testCase.verifyClass(simulation.fault_injection, 'struct');
            testCase.verifyClass(simulation.log_level, 'char');
            testCase.verifyClass(simulation.max_simulation_time, 'double');
            testCase.verifyClass(simulation.metrics, 'struct');
            testCase.verifyClass(simulation.num_random_simulations, 'double');
            testCase.verifyClass(simulation.output_directory, 'char');
            testCase.verifyClass(simulation.random_seed, 'double');
            testCase.verifyClass(simulation.save_interval, 'double');
            testCase.verifyClass(simulation.scenario_file, 'char');
            testCase.verifyClass(simulation.time_step, 'double');
            testCase.verifyClass(simulation.traffic_enabled, 'logical');
            testCase.verifyClass(simulation.update_frequency, 'double');
            testCase.verifyClass(simulation.visualization_enabled, 'logical');
            testCase.verifyClass(simulation.weather_enabled, 'logical');

            % Verify value ranges
            testCase.verifyGreaterThan(simulation.max_simulation_time, 0);
            testCase.verifyGreaterThan(simulation.time_step, 0);
            testCase.verifyGreaterThan(simulation.update_frequency, 0);
            testCase.verifyGreaterThan(simulation.save_interval, 0);
            testCase.verifyGreaterThan(simulation.num_random_simulations, 0);
        end

        function testSonificationSection(testCase)
            % Test that sonification section has all required fields
            sonification = testCase.config.sonification;

            expected_fields = {...
                'enabled', ...
                'max_concurrent_sounds', ...
                'min_interval', ...
                'priority_levels', ...
                'volume', ...
                'warning_sounds' ...
                };

            actual_fields = sort(fieldnames(sonification))';
            testCase.verifyEqual(actual_fields, expected_fields, ...
                'Sonification section missing required fields');

            % Verify field types
            testCase.verifyClass(sonification.enabled, 'logical');
            testCase.verifyClass(sonification.volume, 'double');
            testCase.verifyClass(sonification.warning_sounds, 'struct');
            testCase.verifyClass(sonification.min_interval, 'double');
            testCase.verifyClass(sonification.max_concurrent_sounds, 'double');
            testCase.verifyClass(sonification.priority_levels, 'struct');

            % Verify value ranges
            testCase.verifyGreaterThanOrEqual(sonification.volume, 0);
            testCase.verifyLessThanOrEqual(sonification.volume, 1);
            testCase.verifyGreaterThan(sonification.min_interval, 0);
            testCase.verifyGreaterThan(sonification.max_concurrent_sounds, 0);
        end

        function testVisualizationSection(testCase)
            % Test that visualization section has all required fields
            visualization = testCase.config.visualization;

            expected_fields = {...
                'animation_speed', ...
                'colors', ...
                'display_metrics', ...
                'plot_trajectories', ...
                'refresh_rate', ...
                'show_safety_bounds', ...
                'window_size' ...
                };

            actual_fields = sort(fieldnames(visualization))';
            testCase.verifyEqual(actual_fields, expected_fields, ...
                'Visualization section missing required fields');

            % Verify field types
            testCase.verifyClass(visualization.window_size, 'double');
            testCase.verifyClass(visualization.refresh_rate, 'double');
            testCase.verifyClass(visualization.colors, 'struct');
            testCase.verifyClass(visualization.display_metrics, 'logical');
            testCase.verifyClass(visualization.plot_trajectories, 'logical');
            testCase.verifyClass(visualization.show_safety_bounds, 'logical');
            testCase.verifyClass(visualization.animation_speed, 'double');

            % Verify value ranges
            testCase.verifyGreaterThan(visualization.refresh_rate, 0);
            testCase.verifyGreaterThan(visualization.animation_speed, 0);
            testCase.verifySize(visualization.window_size, [1 2]);
            testCase.verifyGreaterThan(visualization.window_size, [0 0]);
        end
    end
end