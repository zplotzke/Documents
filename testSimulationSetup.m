% TESTSIMULATIONSETUP Test script for simulation setup and configuration
%
% Tests:
% 1. Basic Configuration Loading
% 2. Truck Weight Validation
% 3. Configuration Version Check
% 4. Path Initialization
% 5. Truck Dimensions Constraints
%
% Author: zplotzke
% Last Modified: 2025-02-08 16:47:44 UTC

%% Test Setup
fprintf('Starting simulation setup tests...\n');
tests_passed = 0;
tests_failed = 0;

%% Test 1: Basic Configuration Loading
fprintf('\nTest 1: Basic Configuration Loading\n');
try
    config = getConfig();
    assert(isstruct(config), 'Configuration should be a structure');
    assert(isfield(config, 'truck'), 'Configuration should have truck field');
    assert(isfield(config, 'safety'), 'Configuration should have safety field');
    assert(isfield(config, 'simulation'), 'Configuration should have simulation field');

    fprintf('✓ Basic configuration loading passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ Basic configuration loading failed: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end

%% Test 2: Truck Weight Validation
fprintf('\nTest 2: Truck Weight Validation\n');
try
    config = getConfig();
    weights = config.truck.truck_weights;

    % Check number of weights matches number of trucks
    assert(length(weights) == config.truck.num_trucks, ...
        'Number of weights should match number of trucks');

    % Check weight ranges
    assert(all(weights >= config.truck.min_weight) && ...
        all(weights <= config.truck.max_weight), ...
        sprintf('Weights should be between %d and %d kg', ...
        config.truck.min_weight, config.truck.max_weight));

    fprintf('✓ Truck weight validation passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ Truck weight validation failed: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end

%% Test 3: Configuration Version Check
fprintf('\nTest 3: Configuration Version Check\n');
try
    config = getConfig();
    assert(isfield(config, 'version'), 'Configuration should have version field');
    assert(isfield(config, 'last_modified'), 'Configuration should have last_modified field');

    % Parse and validate timestamp format
    timestamp = datetime(config.last_modified, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
    assert(~isnat(timestamp), 'Last modified should be a valid timestamp');

    fprintf('✓ Configuration version check passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ Configuration version check failed: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end

%% Test 4: Path Initialization
fprintf('\nTest 4: Path Initialization\n');
try
    config = getConfig();
    assert(isfield(config, 'paths'), 'Configuration should have paths field');
    assert(isfield(config.paths, 'data_dir'), 'Paths should include data_dir');
    assert(isfield(config.paths, 'log_dir'), 'Paths should include log_dir');
    assert(isfield(config.paths, 'results_dir'), 'Paths should include results_dir');

    % Check if directories exist
    assert(exist(config.paths.data_dir, 'dir') == 7, 'Data directory should exist');
    assert(exist(config.paths.log_dir, 'dir') == 7, 'Log directory should exist');
    assert(exist(config.paths.results_dir, 'dir') == 7, 'Results directory should exist');

    fprintf('✓ Path initialization passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ Path initialization failed: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end

%% Test 5: Truck Dimensions Constraints
fprintf('\nTest 5: Truck Dimensions Constraints\n');
try
    config = getConfig();

    % Verify weight constraints are documented
    assert(isfield(config.truck, 'min_weight'), 'Should have minimum weight specified');
    assert(isfield(config.truck, 'max_weight'), 'Should have maximum weight specified');

    % Verify length constraints are documented
    assert(isfield(config.truck, 'min_length'), 'Should have minimum length specified');
    assert(isfield(config.truck, 'max_length'), 'Should have maximum length specified');

    % Verify all weights are within constraints
    all_valid_weights = all(config.truck.truck_weights >= config.truck.min_weight) && ...
        all(config.truck.truck_weights <= config.truck.max_weight);
    assert(all_valid_weights, 'All truck weights should be within valid range');

    % Verify all lengths are within constraints
    all_valid_lengths = all(config.truck.truck_lengths >= config.truck.min_length) && ...
        all(config.truck.truck_lengths <= config.truck.max_length);
    assert(all_valid_lengths, 'All truck lengths should be within valid range');

    % Verify constraints are reasonable
    assert(config.truck.min_weight >= 10000, 'Minimum weight should be at least 10,000 kg');
    assert(config.truck.max_weight <= 45000, 'Maximum weight should not exceed 45,000 kg');
    assert(config.truck.min_length >= 10.0, 'Minimum length should be at least 10.0 m');
    assert(config.truck.max_length <= 30.0, 'Maximum length should not exceed 30.0 m');

    fprintf('✓ Truck dimensions constraints validation passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ Truck dimensions constraints validation failed: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end

%% Test 6: Truck Length Validation
fprintf('\nTest 6: Truck Length Validation\n');
try
    config = getConfig();
    lengths = config.truck.truck_lengths;
    
    % Check number of lengths matches number of trucks
    assert(length(lengths) == config.truck.num_trucks, ...
        'Number of lengths should match number of trucks');
    
    % Check length ranges
    assert(all(lengths >= config.truck.min_length) && ...
           all(lengths <= config.truck.max_length), ...
        sprintf('Lengths should be between %.1f and %.1f m', ...
        config.truck.min_length, config.truck.max_length));
    
    % Check for reasonable values
    assert(min(lengths) >= 12.0, 'No truck should be shorter than 12.0 m');
    assert(max(lengths) <= 25.0, 'No truck should be longer than 25.0 m');
    
    % Check if lengths are properly ordered
    assert(all(diff(lengths) >= -10), ...
        'Length differences between consecutive trucks should not exceed 10 m');
        
    fprintf('✓ Truck length validation passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ Truck length validation failed: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end

%% Test Results Summary
fprintf('\n=== Test Results Summary ===\n');
fprintf('Tests Passed: %d\n', tests_passed);
fprintf('Tests Failed: %d\n', tests_failed);
fprintf('Total Tests: %d\n', tests_passed + tests_failed);

if tests_failed == 0
    fprintf('\nAll tests passed successfully!\n');
else
    fprintf('\nSome tests failed. Please review the output above.\n');
end