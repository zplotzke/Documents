classdef PlatoonTestSuite < matlab.unittest.TestCase
    % PLATOONTESTSUITE Test cases for truck platoon simulation
    %
    % Author: zplotzke
    % Last Modified: 2025-02-15 17:18:57 UTC
    % Version: 1.1.16

    properties
        simulation  % TruckPlatoonSimulation instance
        config     % Configuration structure
        logger     % Logger instance
        monitor    % Safety monitor instance
        trainer    % Platoon trainer instance
        network    % LSTM Network instance
    end

    properties (TestParameter)
        simulationTypes = {'training', 'validation', 'final'}  % Types of simulations to test
    end

    methods(TestClassSetup)
        function setupClass(testCase)
            % Initialize logger for tests
            testCase.logger = utils.Logger.getLogger('PlatoonTest');
            testCase.logger.info('Logger initialized by %s', getenv('USERNAME'));

            % Get configuration
            testCase.config = config.getConfig();

            % Test setup started
            testCase.logger.info('Test setup started');
        end
    end

    methods(TestMethodSetup)
        function setupTest(testCase)
            % Create fresh instances for each test
            testCase.logger.info('Test setup started');

            % Initialize simulation
            testCase.simulation = core.TruckPlatoonSimulation();

            % Initialize safety monitor and attach simulation
            testCase.monitor = core.SafetyMonitor();
            testCase.monitor.setSimulation(testCase.simulation);

            % Initialize LSTM network - it will get its config from config.getConfig()
            testCase.network = ml.LSTMNetwork();

            % Initialize trainer with network
            testCase.trainer = core.PlatoonTrainer();
        end
    end

    methods(TestMethodTeardown)
        function teardownTest(testCase)
            testCase.logger.info('Test teardown started');

            % Reset simulation
            if ~isempty(testCase.simulation)
                testCase.simulation.resetSimulation();
            end
        end
    end

    methods(Test)
        function testFullSimulation(testCase, simulationTypes)
            % Test full simulation run with different types
            testCase.simulation.startSimulation(simulationTypes);

            maxSteps = ceil(testCase.config.simulation.duration / testCase.config.simulation.time_step);
            maxIterations = min(maxSteps, 1000);

            history = struct('timeHistory', [], 'stateHistory', []);

            for i = 1:maxIterations
                state = testCase.simulation.step();
                testCase.verifyTrue(testCase.simulation.validateState(), ...
                    sprintf('Invalid simulation state detected at step %d', i));

                % Append to history
                history.timeHistory(end+1) = state.time;
                history.stateHistory(end+1) = state;

                if state.isFinished
                    break;
                end
            end

            % Verify simulation completed successfully
            testCase.verifyTrue(isa(history.timeHistory, 'double'), 'Time history has wrong type');
            testCase.verifyTrue(numel(history.timeHistory) > 0, 'No time history recorded');
            testCase.verifyTrue(numel(history.stateHistory) > 0, 'No state history recorded');
        end

        function testSafetyMonitoring(testCase)
            testCase.simulation.startSimulation('training');

            for i = 1:10
                state = testCase.simulation.step();
                warnings = testCase.monitor.checkSafety();

                testCase.verifyClass(warnings, 'struct');
                testCase.verifyTrue(isfield(warnings, 'level'));
                testCase.verifyTrue(isfield(warnings, 'message'));
            end
        end

        function testTrainingIntegration(testCase)
            testCase.simulation.startSimulation('training');

            for i = 1:5
                state = testCase.simulation.step();
                nextState = predictNextState(testCase.network, state);  % Using predictNextState directly

                testCase.verifyClass(nextState, 'struct');
                testCase.verifyTrue(isfield(nextState, 'positions'));
                testCase.verifyTrue(isfield(nextState, 'velocities'));
                testCase.verifyTrue(isfield(nextState, 'accelerations'));
                testCase.verifyTrue(isfield(nextState, 'jerks'));
                testCase.verifySize(nextState.positions, size(state.positions));
            end
        end

        function testStateValidation(testCase)
            % Initialize simulation and wait for initial spacing to stabilize
            testCase.simulation.startSimulation('training');

            % Run a few more steps to allow initial positions to stabilize
            for i = 1:10
                testCase.simulation.step();
            end

            % Get stabilized state
            state = testCase.simulation.getState();

            % Verify state structure
            testCase.verifyClass(state, 'struct');
            testCase.verifyTrue(isfield(state, 'time'));
            testCase.verifyTrue(isfield(state, 'positions'));
            testCase.verifyTrue(isfield(state, 'velocities'));
            testCase.verifyTrue(isfield(state, 'accelerations'));
            testCase.verifyTrue(isfield(state, 'jerks'));
            testCase.verifyTrue(isfield(state, 'isFinished'));

            % Verify state values
            testCase.verifySize(state.positions, [1, testCase.config.truck.num_trucks]);
            testCase.verifySize(state.velocities, [1, testCase.config.truck.num_trucks]);

            % Verify truck spacing after stabilization
            positions = state.positions;
            minSafeDistance = testCase.config.truck.min_safe_distance;
            for i = 1:(length(positions)-1)
                spacing = positions(i+1) - positions(i);
                testCase.verifyGreaterThanOrEqual(spacing, minSafeDistance, ...
                    sprintf('Unsafe spacing between trucks %d and %d: %.2f < %d', ...
                    i, i+1, spacing, minSafeDistance));
            end
        end
    end
end