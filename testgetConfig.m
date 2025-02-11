function tests = testgetConfig

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% Setup test environment
testCase.TestData.originalDir = pwd;
testCase.TestData.testDir = tempname;
mkdir(testCase.TestData.testDir);
cd(testCase.TestData.testDir);
end

function teardownOnce(testCase)
% Cleanup test environment
cd(testCase.TestData.originalDir);
rmdir(testCase.TestData.testDir, 's');
end

function setup(testCase)
% Per-test setup
warning('off', 'MATLAB:MKDIR:DirectoryExists');
end

function teardown(testCase)
% Per-test cleanup
warning('on', 'MATLAB:MKDIR:DirectoryExists');
end

function testConfigurationVersion(testCase)
% Test configuration version and metadata
config = getConfig();

% Get current timestamp in expected format
current_time = datetime('now', 'TimeZone', 'UTC');
expected_time = string(datetime(current_time, 'Format', 'yyyy-MM-dd HH:mm:ss'));

verifyEqual(testCase, config.version, '1.0.6');
verifyEqual(testCase, config.last_modified_by, 'zplotzke');
% Note: Removed timestamp verification as it changes with each run
end

function testTruckConfiguration(testCase)
% Test truck-specific configuration
config = getConfig();

% Verify number of trucks
verifyEqual(testCase, config.truck.num_trucks, 4);

% Verify truck arrays
verifyTrue(testCase, isequal(size(config.truck.truck_weights), [4, 1]));
verifyTrue(testCase, isequal(size(config.truck.truck_lengths), [4, 1]));

% Verify weight values
expectedWeights = [35000; 32000; 38000; 30000];
verifyEqual(testCase, config.truck.truck_weights, expectedWeights);

% Verify length values
expectedLengths = [16.5; 14.5; 18.0; 15.5];
verifyEqual(testCase, config.truck.truck_lengths, expectedLengths);
end

function testSafetyParameters(testCase)
% Test safety parameter configuration
config = getConfig();

% Verify basic safety parameters exist and have correct values
verifyEqual(testCase, config.safety.min_safe_distance, 10.0);
verifyEqual(testCase, config.safety.max_acceleration, 2.0);
verifyEqual(testCase, config.safety.max_deceleration, -6.0);

% Verify collision thresholds
verifyEqual(testCase, config.safety.collision_thresholds.critical, 0.8);
verifyEqual(testCase, config.safety.collision_thresholds.warning, 1.2);
verifyEqual(testCase, config.safety.collision_thresholds.alert, 1.5);

% Verify warning frequencies
expectedFrequencies = [2.0; 1.0; 1.5; 0.5];
verifyEqual(testCase, config.safety.warning_frequencies, expectedFrequencies);
end

function testSimulationParameters(testCase)
% Test simulation parameter configuration
config = getConfig();

% Verify simulation parameters have correct values
verifyEqual(testCase, config.simulation.frame_rate, 30);
verifyEqual(testCase, config.simulation.final_time, 300);
verifyEqual(testCase, config.simulation.num_random_simulations, 10);
end

function testPathInitialization(testCase)
% Test path initialization
config = getConfig();

% Verify required paths exist
requiredPaths = {'data_dir', 'log_dir', 'results_dir', 'config_backup'};
for i = 1:length(requiredPaths)
    verifyTrue(testCase, isfield(config.paths, requiredPaths{i}));
    verifyTrue(testCase, exist(config.paths.(requiredPaths{i}), 'dir') == 7);
end

% Verify base_dir is current directory
verifyEqual(testCase, config.paths.base_dir, pwd);
end