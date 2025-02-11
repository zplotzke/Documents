classdef PlatoonTestSuite < matlab.unittest.TestCase
    % PLATOONTESTSUITE Test suite for truck platoon simulation
    %
    % Tests functionality of:
    % - Core simulation components
    % - Safety monitoring
    % - LSTM predictions
    % - Visualization
    %
    % Author: zplotzke
    % Last Modified: 2025-02-11 15:25:44 UTC
    % Version: 1.0.0

    properties (TestParameter)
        NumTrucks = {2, 3, 4, 5}
        SimDuration = {10, 30, 60}
    end

    properties
        config
        logger
    end

    methods (TestClassSetup)
        function setupTestClass(testCase)
            % Set up test class
            testCase.config = config.getConfig();
            testCase.logger = utils.Logger.getLogger('PlatoonTest');

            % Modify config for testing
            testCase.config.simulation.random_seed = 42;
            testCase.config.visualization.show_predictions = false;
        end
    end

    methods (Test)
        function testSimulationInitialization(testCase, NumTrucks)
            % Test simulation initialization
            testCase.config.truck.num_trucks = NumTrucks;
            sim = core.TruckPlatoonSimulation(testCase.config);

            state = sim.getState();
            testCase.verifyEqual(length(state.positions), NumTrucks, ...
                'Number of trucks does not match configuration');

            testCase.verifyEqual(state.time, 0, ...
                'Initial time should be 0');

            testCase.verifyFalse(sim.isFinished(), ...
                'Simulation should not be finished at start');
        end

        function testSafetyMonitor(testCase)
            % Test safety monitoring functionality
            monitor = core.SafetyMonitor(testCase.config);

            % Test safe conditions
            positions = [100 80 60 40];
            velocities = [20 20 20 20];
            accelerations = zeros(1,4);
            jerks = zeros(1,4);

            [is_safe, violations] = monitor.checkSafetyConditions(...
                positions, velocities, accelerations, jerks);

            testCase.verifyTrue(is_safe, ...
                'Safe conditions reported as unsafe');
            testCase.verifyEmpty(violations, ...
                'Violations reported for safe conditions');

            % Test unsafe conditions
            positions = [100 95 90 85];  % Too close
            velocities = [30 30 30 30];  % Max speed violation

            [is_safe, violations] = monitor.checkSafetyConditions(...
                positions, velocities, accelerations, jerks);

            testCase.verifyFalse(is_safe, ...
                'Unsafe conditions reported as safe');
            testCase.verifyNotEmpty(violations, ...
                'No violations reported for unsafe conditions');
        end

        function testPlatoonTrainer(testCase)
            % Test LSTM trainer functionality
            trainer = core.PlatoonTrainer(testCase.config);

            % Generate some training data
            for t = 0:0.1:1
                state.time = t;
                state.positions = [100 80 60 40] + t * 20;
                state.velocities = ones(1,4) * 20;
                state.accelerations = zeros(1,4);
                state.jerks = zeros(1,4);

                trainer.collectSimulationData(state);
            end

            % Test network training
            testCase.verifyWarningFree(@() trainer.trainNetwork(), ...
                'Network training generated warnings');

            net = trainer.getNetwork();
            testCase.verifyNotEmpty(net, ...
                'Trained network is empty');
        end

        function testStatePrediction(testCase)
            % Test state prediction functionality
            % Create and train network with sample data
            trainer = core.PlatoonTrainer(testCase.config);
            generateTrainingData(trainer);
            trainer.trainNetwork();
            network = trainer.getNetwork();

            % Test prediction
            state.positions = [100 80 60 40];
            state.velocities = [20 20 20 20];
            state.accelerations = zeros(1,4);
            state.jerks = zeros(1,4);

            predictions = ml.predictNextState(network, state);

            testCase.verifyTrue(isstruct(predictions), ...
                'Predictions should be a structure');

            required_fields = {'positions', 'velocities', ...
                'accelerations', 'jerks'};

            for i = 1:length(required_fields)
                testCase.verifyTrue(isfield(predictions, required_fields{i}), ...
                    sprintf('Predictions missing field: %s', required_fields{i}));
            end
        end

        function testSimulationCompletion(testCase, SimDuration)
            % Test simulation completion
            testCase.config.simulation.duration = SimDuration;
            sim = core.TruckPlatoonSimulation(testCase.config);

            steps = 0;
            max_steps = SimDuration / testCase.config.simulation.time_step;

            while ~sim.isFinished() && steps < max_steps
                sim.step();
                steps = steps + 1;
            end

            testCase.verifyTrue(sim.isFinished(), ...
                'Simulation did not complete');

            state = sim.getState();
            testCase.verifyGreaterThanOrEqual(state.time, ...
                min(SimDuration, testCase.config.simulation.duration), ...
                'Simulation ended too early');
        end

        function testVisualization(testCase)
            % Test visualization functionality
            viz = viz.PlatoonVisualizer(testCase.config);

            % Test initialization
            testCase.verifyWarningFree(@() viz.initialize(), ...
                'Visualization initialization generated warnings');

            % Test update with sample state
            state.time = 0;
            state.positions = [100 80 60 40];
            state.velocities = [20 20 20 20];
            state.accelerations = zeros(1,4);
            state.jerks = zeros(1,4);

            testCase.verifyWarningFree(@() viz.update(state), ...
                'Visualization update generated warnings');

            % Test warning display
            warnings = {
                struct('type', 'DISTANCE', ...
                'message', 'Test warning', ...
                'data', struct('time', 0, 'distance', 10))
                };

            testCase.verifyWarningFree(@() viz.showWarnings(warnings), ...
                'Warning display generated warnings');

            % Clean up
            close all;
        end
    end

    methods (Access = private)
        function generateTrainingData(trainer)
            % Generate sample training data
            for t = 0:0.1:10
                state.time = t;
                state.positions = [100 80 60 40] + t * 20;
                state.velocities = ones(1,4) * 20;
                state.accelerations = zeros(1,4);
                state.jerks = zeros(1,4);

                trainer.collectSimulationData(state);
            end
        end
    end
end