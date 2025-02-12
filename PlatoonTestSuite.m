classdef PlatoonTestSuite < matlab.unittest.TestCase
    % PLATOONTESTSUITE Test suite for truck platoon simulation
    %
    % Tests core functionality for:
    % - Simulation state management and physics
    % - Safety monitoring and warnings
    % - LSTM training and prediction
    % - Configuration validation
    %
    % Author: zplotzke
    % Last Modified: 2025-02-12 02:00:07 UTC
    % Version: 1.0.9

    properties (TestParameter)
        SimModes = {'Normal', 'Emergency', 'Degraded'}
        PlatoonSizes = {2, 3, 4, 5}
        WarningTypes = {'COLLISION', 'SPEED', 'DISTANCE', 'EMERGENCY_BRAKE'}
    end

    properties
        simulation
        safetyMonitor
        trainer
        config
        logger
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            testCase.config = config.getConfig();
            testCase.logger = utils.Logger.getLogger('PlatoonTest');
            testCase.logger.setLevel('DEBUG');
            testCase.validateConfigFields();
        end
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.simulation = core.TruckPlatoonSimulation(testCase.config);
            testCase.safetyMonitor = core.SafetyMonitor(testCase.config);
            testCase.trainer = core.PlatoonTrainer(testCase.config);
        end
    end

    methods (Test)
        function testConfigFields(testCase)
            % Verify essential configuration fields
            testCase.verifyTrue(isfield(testCase.config, 'simulation'), ...
                'Missing simulation configuration section');
            testCase.verifyTrue(isfield(testCase.config.simulation, 'time_step'), ...
                'Missing time_step in simulation configuration');
            testCase.verifyTrue(isfield(testCase.config, 'truck'), ...
                'Missing truck configuration section');
            testCase.verifyTrue(isfield(testCase.config, 'safety'), ...
                'Missing safety configuration section');
        end

        function testSimulationStep(testCase)
            % Create a custom config for simulation step test
            custom_config = testCase.config;
            custom_config.simulation.time_step = 0.1; % 100ms for precise testing
            custom_config.truck.initial_velocity = 0;  % Start from rest
            custom_config.truck.constant_acceleration = 2.0;  % Constant 2 m/s^2

            % Create new simulation with custom config
            sim = core.TruckPlatoonSimulation(custom_config);
            initial_state = sim.getState();

            % Step simulation
            state = sim.step();

            % Calculate expected values for first time step
            dt = custom_config.simulation.time_step;
            expected_velocity = custom_config.truck.constant_acceleration * dt;
            expected_position = 0.5 * custom_config.truck.constant_acceleration * dt^2;

            % Get actual movement
            actual_velocity = state.velocities(1);
            actual_position = state.positions(1) - initial_state.positions(1);
            actual_acceleration = state.accelerations(1);

            % Verify time increment
            testCase.verifyEqual(state.time, dt, ...
                'AbsTol', 1e-6, ...
                sprintf('Time step incorrect. Expected %f, got %f', dt, state.time));

            % Verify acceleration
            testCase.verifyEqual(actual_acceleration, custom_config.truck.constant_acceleration, ...
                'AbsTol', 1e-6, ...
                sprintf('Acceleration incorrect. Expected %f, got %f', ...
                custom_config.truck.constant_acceleration, actual_acceleration));

            % Verify velocity
            testCase.verifyEqual(actual_velocity, expected_velocity, ...
                'AbsTol', 1e-6, ...
                sprintf('Velocity incorrect. Expected %f, got %f', ...
                expected_velocity, actual_velocity));

            % Verify position change
            testCase.verifyGreaterThan(actual_position, 0, ...
                sprintf('No movement detected. Position change: %f', actual_position));

            testCase.verifyEqual(actual_position, expected_position, ...
                'AbsTol', 1e-6, ...
                sprintf('Position incorrect. Expected %f, got %f', ...
                expected_position, actual_position));
        end

        function testParameterRandomization(testCase)
            initial_state = testCase.simulation.getState();

            % Step simulation to see parameter effects
            state = testCase.simulation.step();

            % Verify velocity bounds
            testCase.verifyLessThanOrEqual(max(abs(state.velocities)), ...
                testCase.config.truck.max_velocity, ...
                'Velocity exceeds maximum limit');
            testCase.verifyGreaterThanOrEqual(min(state.velocities), 0, ...
                'Negative velocities found');

            % Verify acceleration bounds
            testCase.verifyLessThanOrEqual(max(abs(state.accelerations)), ...
                testCase.config.truck.max_acceleration, ...
                'Acceleration exceeds maximum limit');
        end

        function testSafetyViolationDetection(testCase)
            % Set up a clear safety violation
            positions = [100; 95];  % 5m gap (less than min_safe_distance)
            velocities = [20; 25];  % Following vehicle faster
            accelerations = [0; 2]; % Following vehicle accelerating
            jerks = [0; 0];

            % Get safety thresholds from config
            min_safe_distance = testCase.config.truck.min_safe_distance;
            min_time_gap = testCase.config.safety.min_following_time;

            % Ensure we're actually creating a violation
            gap = positions(1) - positions(2);
            time_based_dist = velocities(2) * min_time_gap;

            testCase.verifyLessThan(gap, min_safe_distance, ...
                'Test setup: Gap should be less than minimum safe distance');
            testCase.verifyLessThan(gap, time_based_dist, ...
                'Test setup: Gap should be less than time-based safe distance');

            % Check safety conditions
            [is_safe, violations] = testCase.safetyMonitor.checkSafetyConditions(...
                positions, velocities, accelerations, jerks);

            % Verify results
            testCase.verifyFalse(is_safe, 'Should detect safety violation');
            testCase.verifyNotEmpty(violations, 'Should return violation details');
        end

        function testWarningSystem(testCase, WarningTypes)
            % Create test warning data
            warning_data = struct('truck', 1, 'value', 0);

            % Raise warning
            testCase.safetyMonitor.warnings.raiseWarning(WarningTypes, ...
                sprintf('Test %s warning', WarningTypes), warning_data);

            % Verify warning was recorded
            stats = testCase.safetyMonitor.warnings.getWarningStats();
            testCase.verifyTrue(stats.counts(WarningTypes) > 0, ...
                sprintf('%s warning not recorded', WarningTypes));
        end

        function testTrainerInitialization(testCase)
            metrics = testCase.trainer.getTrainingMetrics();
            testCase.verifyTrue(isstruct(metrics), 'Training metrics should be a struct');
            testCase.verifyTrue(isfield(metrics, 'trainRMSE'), 'Missing trainRMSE field');
            testCase.verifyTrue(isfield(metrics, 'valRMSE'), 'Missing valRMSE field');
        end

        function testDataCollection(testCase)
            % Run simulation and collect data
            initial_state = testCase.simulation.getState();
            testCase.trainer.collectSimulationData(initial_state);

            % Step simulation and collect more data
            for i = 1:5
                state = testCase.simulation.step();
                testCase.trainer.collectSimulationData(state);
            end

            % Verify data collection
            metrics = testCase.trainer.getTrainingMetrics();
            testCase.verifyTrue(~isempty(metrics), 'No training metrics after data collection');
        end

        function testStatePrediction(testCase)
            % Skip this test until LSTM implementation is complete
            testCase.assumeTrue(false, 'LSTM functionality not yet implemented');
        end
    end

    methods (Access = private)
        function validateConfigFields(testCase)
            % Validate all required configuration fields are present
            required_fields = {
                'simulation.time_step'
                'simulation.duration'
                'truck.num_trucks'
                'truck.initial_spacing'
                'truck.min_safe_distance'
                'truck.max_velocity'
                'truck.max_acceleration'
                'safety.min_following_time'
                'safety.emergency_decel_threshold'
                };

            for i = 1:length(required_fields)
                field_parts = strsplit(required_fields{i}, '.');
                if isscalar(field_parts)
                    testCase.verifyTrue(isfield(testCase.config, field_parts{1}), ...
                        sprintf('Missing required config field: %s', required_fields{i}));
                else
                    testCase.verifyTrue(isfield(testCase.config.(field_parts{1}), field_parts{2}), ...
                        sprintf('Missing required config field: %s', required_fields{i}));
                end
            end
        end
    end
end