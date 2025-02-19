classdef PlatoonTestSuite < matlab.unittest.TestCase
    % PLATOONTESTSUITE Test cases for truck platoon simulation
    %
    % Tests the integration and functionality of:
    % - Safety monitoring
    % - Warning system
    % - Sonification
    % - Simulation control
    %
    % Author: zplotzke
    % Last Modified: 2025-02-19 15:27:10 UTC
    % Version: 1.1.20

    properties
        simulation      % TruckPlatoonSimulation instance
        config         % Configuration structure
        logger         % Logger instance
        monitor        % Safety monitor instance
        trainer        % Platoon trainer instance
        network        % LSTM Network instance
        warningSystem  % Warning system instance
        sonificator    % Sonification system instance
    end

    methods(TestMethodSetup)
        function setupTest(testCase)
            % Initialize test components
            testCase.config = config.getConfig();
            testCase.logger = utils.Logger.getLogger('PlatoonTestSuite');
            testCase.logger.info('Test setup started');

            % Initialize simulation components
            testCase.simulation = core.TruckPlatoonSimulation();
            testCase.monitor = core.SafetyMonitor();
            testCase.warningSystem = utils.WarningSystem();
            testCase.sonificator = utils.Sonificator();

            % Connect components
            testCase.monitor.setSimulation(testCase.simulation);
            testCase.monitor.setWarningSystem(testCase.warningSystem);

            % Initialize ML components
            testCase.network = ml.LSTMNetwork();
            testCase.trainer = core.PlatoonTrainer();
        end
    end

    methods(Test)
        function testWarningWithSonification(testCase)
            % Test integration of warning system with sonification
            testCase.simulation.startSimulation('training');

            % Force a safety violation by creating unsafe positions
            positions = [0, 5, 10, 15];  % Trucks too close together
            velocities = [20, 20, 20, 20];  % All trucks at constant speed
            accelerations = [0, 0, 0, 0];
            jerks = [0, 0, 0, 0];

            % Check safety conditions with forced violation
            [is_safe, violations] = testCase.monitor.checkSafetyConditions(...
                positions, ...
                velocities, ...
                accelerations, ...
                jerks);

            % Verify safety check results
            testCase.verifyFalse(is_safe, 'Safety check should fail with forced violation');
            warnings = testCase.warningSystem.getActiveWarnings();
            testCase.verifyNotEmpty(warnings, 'Warning should be generated');

            % Verify sonification state
            testCase.verifyTrue(testCase.sonificator.getEnabled(), ...
                'Sonificator should be enabled');
        end

        function testSonificationControl(testCase)
            % Test enabling/disabling sonification
            testCase.sonificator.disable();
            testCase.verifyFalse(testCase.sonificator.getEnabled(), ...
                'Sonificator should be disabled');

            testCase.sonificator.enable();
            testCase.verifyTrue(testCase.sonificator.getEnabled(), ...
                'Sonificator should be enabled');
        end

        function testWarningPriorities(testCase)
            % Test that different warning types trigger appropriate sounds
            warningTypes = {'COLLISION', 'EMERGENCY_BRAKE', 'DISTANCE', 'SPEED'};

            for i = 1:length(warningTypes)
                testCase.warningSystem.clearWarnings();  % Clear previous warnings

                testCase.warningSystem.raiseWarning(warningTypes{i}, ...
                    'Test warning', struct('severity', 0.5));

                warnings = testCase.warningSystem.getActiveWarnings();
                testCase.verifyEqual(warnings{end}.type, warningTypes{i}, ...
                    'Warning type should match');

                pause(0.3); % Allow time between warnings
            end
        end

        function testWarningSystemIntegration(testCase)
            % Test warning system integration with simulation
            testCase.simulation.startSimulation('training');

            % Force a safety violation
            state = testCase.simulation.getState();
            state.positions = [0, 5, 10, 15]; % Unsafe following distances
            testCase.simulation.setState(state);

            % Check safety and verify warning generation
            [is_safe, violations] = testCase.monitor.checkSafetyConditions(...
                state.positions, ...
                state.velocities, ...
                state.accelerations, ...
                state.jerks);

            % Verify results
            testCase.verifyFalse(is_safe, 'Safety violation should be detected');
            warnings = testCase.warningSystem.getActiveWarnings();
            testCase.verifyNotEmpty(warnings, 'Warning should be generated');
        end

        function testSimulationReset(testCase)
            % Test simulation reset functionality
            testCase.simulation.startSimulation('training');
            initial_state = testCase.simulation.getState();

            % Run simulation for a few steps
            for i = 1:5
                testCase.simulation.step();
            end

            % Reset simulation
            testCase.simulation.reset();
            reset_state = testCase.simulation.getState();

            % Verify reset state matches initial state
            testCase.verifyEqual(reset_state.positions, initial_state.positions, ...
                'Positions should reset to initial values');
            testCase.verifyEqual(reset_state.velocities, initial_state.velocities, ...
                'Velocities should reset to initial values');
        end

        function testWarningTimeouts(testCase)
            % Test warning timeout functionality
            testCase.warningSystem.clearWarnings();

            % Raise initial warning
            testCase.warningSystem.raiseWarning('COLLISION', 'Initial warning', ...
                struct('severity', 1.0));

            % Get initial warning count
            initialWarnings = testCase.warningSystem.getActiveWarnings();
            initialCount = length(initialWarnings);

            % Attempt to raise same warning immediately
            testCase.warningSystem.raiseWarning('COLLISION', 'Repeated warning', ...
                struct('severity', 1.0));

            % Verify warning count hasn't changed due to timeout
            currentWarnings = testCase.warningSystem.getActiveWarnings();
            testCase.verifyEqual(length(currentWarnings), initialCount, ...
                'Duplicate warning should be prevented by timeout');
        end

        function testSeverityLevels(testCase)
            % Test different severity levels for warnings
            severityLevels = [0.2, 0.5, 0.8, 1.0];
            warningCount = 0;

            for severity = severityLevels
                testCase.warningSystem.clearWarnings();  % Clear previous warnings

                testCase.warningSystem.raiseWarning('COLLISION', ...
                    sprintf('Warning with severity %.1f', severity), ...
                    struct('severity', severity));
                warningCount = warningCount + 1;

                % Verify warning generation and severity
                warnings = testCase.warningSystem.getActiveWarnings();
                testCase.verifyEqual(length(warnings), 1, ...
                    sprintf('Warning should be generated for severity %.1f', severity));
                testCase.verifyEqual(warnings{1}.data.severity, severity, ...
                    'Warning severity should match');

                pause(0.5); % Ensure enough time between warnings
            end

            % Verify total warnings generated
            testCase.verifyEqual(warningCount, length(severityLevels), ...
                'All severity levels should generate warnings');
        end
    end

    methods(TestMethodTeardown)
        function teardownTest(testCase)
            % Clean up after each test
            testCase.warningSystem.clearWarnings();
            testCase.simulation.reset();
            testCase.logger.info('Test teardown completed');
        end
    end
end