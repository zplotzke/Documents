function tests = testrunTruckPlatoonSimulation
% TESTRUNTRUCKPLATOONSIMULATION Test suite for truck platoon simulation runner
%
% Tests the main simulation entry point including:
% - Basic simulation operation
% - Error handling
%
% Author: zplotzke
% Last Modified: 2025-02-11 04:33:50 UTC

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% Setup test environment
testCase.TestData.originalDir = pwd;
testCase.TestData.testDir = tempname;
mkdir(testCase.TestData.testDir);
cd(testCase.TestData.testDir);

% Create base config for testing
testCase.TestData.baseConfig = struct(...
    'truck', struct(...
    'num_trucks', 4, ...
    'truck_weights', ones(4,1), ...
    'truck_lengths', ones(4,1), ...
    'initial_speed', 20, ...
    'desired_gap', 10, ...
    'max_relative_velocity', 5), ...
    'safety', struct(...
    'min_safe_distance', 10, ...
    'max_acceleration', 2, ...
    'max_jerk', 1), ...
    'simulation', struct(...
    'frame_rate', 30, ...
    'final_time', 100, ...
    'num_random_simulations', 1));
end

function teardownOnce(testCase)
% Cleanup test environment
cd(testCase.TestData.originalDir);
rmdir(testCase.TestData.testDir, 's');
end

function testBasicSimulationOperation(testCase)
% Set up mocks in base workspace
assignin('base', 'getConfig', @() testCase.TestData.baseConfig);
assignin('base', 'Logger', createMockLogger());

% Run simulation
runTruckPlatoonSimulation();

% No explicit verification needed - if simulation completes without error,
% the test passes
end

function testSimulationError(testCase)
% Create invalid config that should trigger an error
errorConfig = testCase.TestData.baseConfig;
errorConfig.safety.min_safe_distance = -1; % Invalid safety distance

% Set up mocks in base workspace
assignin('base', 'getConfig', @() errorConfig);
assignin('base', 'Logger', createMockLogger());

% Verify error is thrown and caught properly
verifyError(testCase, @runTruckPlatoonSimulation, 'Simulation:SafetyConstraint');
end

function logger = createMockLogger()
logger = struct();
logger.getLogger = @(~) struct('info', @(varargin) [], 'error', @(varargin) []);
end