classdef PlatoonTestSuite < matlab.unittest.TestCase
    % PLATOONTESTSUITE Integration tests for truck platoon system
    %
    % Tests the integration of major system components:
    % - Full simulation cycle
    % - Safety monitoring system
    % - Training system integration
    % - State validation
    %
    % Author: zplotzke
    % Last Modified: 2025-02-15 03:24:55 UTC
    % Version: 1.0.3

    properties (TestParameter)
        simulationTypes = {'training', 'validation', 'final'}
    end

    properties
        simulation      % TruckPlatoonSimulation instance
        trainer         % PlatoonTrainer instance
        safety_monitor  % SafetyMonitor instance
        logger         % Logger instance
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            % Initialize logger
            testCase.logger = utils.Logger.getLogger('PlatoonTestSuite');
            testCase.logger.info('Test setup started');

            % Initialize components
            testCase.simulation = TruckPlatoonSimulation();
            testCase.trainer = PlatoonTrainer();
            testCase.safety_monitor = SafetyMonitor();

            testCase.logger.info('Test setup completed');
        end
    end

    methods (TestMethodTeardown)
        function teardownTest(testCase)
            testCase.logger.info('Test teardown started');
            testCase.simulation.resetSimulation();
            testCase.logger.info('Test teardown completed');
        end
    end

    methods (Test)
        function testFullSimulation(testCase, simulationTypes)
            % Test complete simulation cycle
            testCase.logger.info('Starting full simulation test: %s', simulationTypes);

            % Run simulation with different configurations based on type
            switch simulationTypes
                case 'training'
                    testCase.runTrainingSimulation();
                case 'validation'
                    testCase.runValidationSimulation();
                case 'final'
                    testCase.runFinalSimulation();
            end

            testCase.logger.info('Full simulation test completed: %s', simulationTypes);
        end

        function testSafetyMonitoring(testCase)
            % Test safety monitoring integration
            testCase.logger.info('Starting safety monitoring test');
            testCase.checkSafetySystem();
            testCase.logger.info('Safety monitoring test completed');
        end

        function testTrainingIntegration(testCase)
            % Test training system integration
            testCase.logger.info('Starting training integration test');
            testCase.validateTrainingSystem();
            testCase.logger.info('Training integration test completed');
        end

        function testStateValidation(testCase)
            % Test state validation
            testCase.logger.info('Starting state validation test');
            state = testCase.simulation.step();
            testCase.validateSimulationState(state);
            testCase.logger.info('State validation test completed');
        end
    end

    methods (Access = private)
        function runTrainingSimulation(testCase)
            % Run training simulation cycle
            while ~testCase.simulation.isFinished()
                state = testCase.simulation.step();
                testCase.trainer.collectSimulationData(state);
                testCase.validateSimulationState(state);
            end
        end

        function runValidationSimulation(testCase)
            % Run validation simulation cycle
            while ~testCase.simulation.isFinished()
                state = testCase.simulation.step();
                testCase.validateSimulationState(state);
                testCase.trainer.validateModel(state);
            end
        end

        function runFinalSimulation(testCase)
            % Run final simulation cycle
            while ~testCase.simulation.isFinished()
                state = testCase.simulation.step();
                testCase.validateSimulationState(state);
                testCase.trainer.predictNextState(state);
            end
        end

        function checkSafetySystem(testCase)
            % Validate safety system integration
            state = testCase.simulation.getState();
            [is_safe, violations] = testCase.safety_monitor.checkSafetyConditions(...
                state.positions, state.velocities, state.accelerations);

            testCase.verifyTrue(~isempty(violations) || is_safe, ...
                'Safety check inconsistency');
            testCase.logger.info('Safety system check completed: safe=%d', is_safe);
        end

        function validateTrainingSystem(testCase)
            % Validate training system integration
            state = testCase.simulation.getState();
            testCase.trainer.collectSimulationData(state);

            testCase.verifyGreaterThan(testCase.trainer.DatasetSize, 0, ...
                'Training data not collected');
            testCase.logger.info('Training system validation completed: dataset size=%d', ...
                testCase.trainer.DatasetSize);
        end

        function validateSimulationState(testCase, state)
            % Validate simulation state
            testCase.verifyGreaterThanOrEqual(state.time, 0, ...
                'Invalid simulation time');

            [is_safe, ~] = testCase.safety_monitor.checkSafetyConditions(...
                state.positions, state.velocities, state.accelerations);

            testCase.verifyTrue(is_safe, 'Safety conditions violated');
            testCase.logger.debug('State validation completed: time=%.2f, safe=%d', ...
                state.time, is_safe);
        end
    end
end