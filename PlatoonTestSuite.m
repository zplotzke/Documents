classdef PlatoonTestSuite < matlab.unittest.TestCase
    % PLATOONTESTSUITE Test suite for truck platoon simulation
    %
    % Complete test suite for verifying platoon simulation core functionality:
    % - System configuration and initialization
    % - Vehicle dynamics and control
    % - Communication and sensor systems
    % - Safety features and emergency handling
    % - Environment simulation
    %
    % Note: Logging functionality is tested separately in LoggerTest
    %
    % Author: zplotzke
    % Last Modified: 2025-02-11 20:56:04 UTC
    % Version: 1.0.0

    properties (TestParameter)
        VehicleTypes = {'Truck', 'Car'}
        PlatoonSizes = {1, 2, 3, 5}
        SimModes = {'Normal', 'Emergency', 'Degraded'}
        TerrainTypes = {'Flat', 'Hilly', 'Urban'}
        WeatherConditions = {'Clear', 'Rain', 'Snow'}
    end

    properties
        platoon
        vehicles
        environment
        logger
        config
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            % Initialize test environment using existing config system
            testCase.config = config.getConfig();
            testCase.logger = utils.Logger.getLogger('PlatoonTest');
            testCase.logger.setLevel('DEBUG');  % Set default level for tests
        end
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            % Fresh setup for each test
            testCase.environment = utils.Environment();
            testCase.platoon = utils.Platoon();
            testCase.vehicles = {};
        end
    end

    methods (Test)
        % System Configuration Tests
        function testSystemConfig(testCase)
            testCase.verifyTrue(isfield(testCase.config, 'simulationMode'), ...
                'Configuration missing simulationMode');
            testCase.verifyTrue(isfield(testCase.config, 'updateRate'), ...
                'Configuration missing updateRate');
            testCase.verifyEqual(testCase.config.simulationMode, 'Normal');
            testCase.verifyGreaterThan(testCase.config.updateRate, 0);
        end

        % Vehicle Tests
        function testVehicleTypes(testCase, VehicleTypes)
            vehicle = utils.Vehicle(VehicleTypes);
            testCase.verifyClass(vehicle, 'utils.Vehicle');
            testCase.verifyEqual(vehicle.getType(), VehicleTypes);
            testCase.verifyTrue(vehicle.isOperational());
        end

        % Environment Tests
        function testEnvironmentSetup(testCase, TerrainTypes, WeatherConditions)
            testCase.environment.setTerrain(TerrainTypes);
            testCase.environment.setWeather(WeatherConditions);

            testCase.verifyEqual(testCase.environment.getTerrain(), TerrainTypes);
            testCase.verifyEqual(testCase.environment.getWeather(), WeatherConditions);
            testCase.verifyTrue(testCase.environment.isSimulationReady());
        end

        % Platoon Formation Tests
        function testPlatoonFormation(testCase, PlatoonSizes)
            vehicles = testCase.createVehicles(PlatoonSizes);
            testCase.platoon.addVehicles(vehicles);

            testCase.verifyEqual(testCase.platoon.getSize(), PlatoonSizes);
            testCase.verifyTrue(testCase.platoon.isFormationValid());
        end

        % Communication Tests
        function testVehicleCommunication(testCase)
            testCase.platoon.addVehicles(testCase.createVehicles(3));

            message = struct('type', 'SPEED_CHANGE', 'value', 60);
            success = testCase.platoon.broadcastMessage(message);

            testCase.verifyTrue(success, 'Message broadcast failed');
            testCase.verifyEqual(testCase.platoon.getLastMessage(), message);
        end

        % Sensor Fusion Tests
        function testSensorFusion(testCase)
            vehicle = utils.Vehicle('Truck');
            sensorData = vehicle.getSensorData();

            testCase.verifyTrue(isstruct(sensorData));
            testCase.verifyField(sensorData, 'position');
            testCase.verifyField(sensorData, 'velocity');
            testCase.verifyField(sensorData, 'acceleration');
        end

        % Control System Tests
        function testControlSystem(testCase)
            controller = utils.PlatoonController();
            vehicle = utils.Vehicle('Truck');

            controller.setTarget(vehicle, struct('speed', 60, 'gap', 20));
            response = controller.getControlOutput(vehicle);

            testCase.verifyTrue(isstruct(response));
            testCase.verifyField(response, 'throttle');
            testCase.verifyField(response, 'brake');
            testCase.verifyField(response, 'steering');
        end

        % Safety System Tests
        function testSafetySystems(testCase, SimModes)
            testCase.platoon.addVehicles(testCase.createVehicles(3));
            testCase.platoon.setMode(SimModes);

            if strcmp(SimModes, 'Emergency')
                testCase.verifyTrue(testCase.platoon.isEmergencyMode());
                testCase.verifyTrue(all([testCase.platoon.vehicles.isBraking]));
            end
        end

        % Performance Tests
        function testSystemPerformance(testCase)
            testCase.platoon.addVehicles(testCase.createVehicles(5));

            tic;
            testCase.platoon.updateState();
            updateTime = toc;

            maxUpdateTime = 0.01; % 10ms maximum update time
            testCase.verifyLessThan(updateTime, maxUpdateTime, ...
                'System update time exceeds performance requirement');
        end
    end

    methods (Access = private)
        function vehicles = createVehicles(testCase, count)
            % Helper method to create test vehicles
            vehicles = cell(1, count);
            for i = 1:count
                vehicles{i} = utils.Vehicle('Truck');
            end
        end
    end
end