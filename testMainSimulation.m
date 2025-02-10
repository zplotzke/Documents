% TESTMAINSIMULATION Test suite for mainSimulation class
%
% Author: zplotzke
% Last Modified: 2025-02-08 17:02:06 UTC

%% Test Setup
fprintf('Starting mainSimulation tests...\n');
tests_passed = 0;
tests_failed = 0;

%% Test 1: Basic Initialization
fprintf('\nTest 1: Basic Initialization\n');
try
    sim = mainSimulation();

    assert(isstruct(sim.config), 'Configuration should be a structure');
    assert(isnumeric(sim.currentTime), 'Current time should be numeric');
    assert(sim.currentTime == 0, 'Initial time should be 0');
    assert(~isempty(sim.getTruckPositions()), 'Truck positions should be initialized');

    fprintf('✓ Basic initialization passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ Basic initialization failed: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end

%% Test 2: Truck Configuration
fprintf('\nTest 2: Truck Configuration\n');
try
    sim = mainSimulation();

    positions = sim.getTruckPositions();
    velocities = sim.getTruckVelocities();

    assert(length(positions) == sim.config.truck.num_trucks, ...
        'Number of trucks should match configuration');

    assert(all(velocities == sim.config.truck.initial_speed), ...
        'Initial velocities should match configuration');

    fprintf('✓ Truck configuration passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ Truck configuration failed: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end

%% Test 3: Reset Functionality
fprintf('\nTest 3: Reset Functionality\n');
try
    sim = mainSimulation();
    initial_positions = sim.getTruckPositions();
    initial_velocities = sim.getTruckVelocities();

    % Run a few steps
    for i = 1:5
        sim.step();
    end

    % Reset simulation
    sim.reset();

    assert(sim.currentTime == 0, 'Time should reset to 0');
    assert(all(sim.getTruckPositions() == initial_positions), ...
        'Positions should reset to initial values');
    assert(all(sim.getTruckVelocities() == initial_velocities), ...
        'Velocities should reset to initial values');

    fprintf('✓ Reset functionality passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ Reset functionality failed: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end

%% Test 4: Single Step Execution
fprintf('\nTest 4: Single Step Execution\n');
try
    sim = mainSimulation();
    initial_positions = sim.getTruckPositions();

    success = sim.step();

    assert(success, 'Step should execute successfully');
    assert(sim.currentTime == 1/sim.config.simulation.frame_rate, ...
        'Time should advance by one frame');
    assert(~all(sim.getTruckPositions() == initial_positions), ...
        'Positions should update after step');

    fprintf('✓ Single step execution passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ Single step execution failed: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end

%% Test 5: Safety Constraints
fprintf('\nTest 5: Safety Constraints\n');
try
    sim = mainSimulation();
    state = sim.getState();

    assert(state.isValid, 'Initial state should satisfy safety constraints');

    positions = sim.getTruckPositions();
    lengths = state.lengths;

    % Check minimum distance constraint
    for i = 1:length(positions)-1
        distance = positions(i) - positions(i+1) - lengths(i);
        assert(distance >= sim.config.safety.min_safe_distance, ...
            'Initial truck spacing should satisfy minimum safe distance');
    end

    fprintf('✓ Safety constraints passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ Safety constraints failed: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end

%% Test 6: Time History Recording
fprintf('\nTest 6: Time History Recording\n');
try
    sim = mainSimulation();

    num_steps = 10;
    for i = 1:num_steps
        sim.step();
    end

    assert(length(sim.timeHistory.times) == num_steps + 1, ...
        'Time history should record all steps');
    assert(size(sim.timeHistory.positions, 2) == num_steps + 1, ...
        'Position history should record all steps');

    fprintf('✓ Time history recording passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ Time history recording failed: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end

%% Test 7: State Access
fprintf('\nTest 7: State Access\n');
try
    sim = mainSimulation();
    state = sim.getState();

    assert(isfield(state, 'time'), 'State should include time');
    assert(isfield(state, 'positions'), 'State should include positions');
    assert(isfield(state, 'velocities'), 'State should include velocities');
    assert(isfield(state, 'isValid'), 'State should include validity flag');
    assert(state.time == sim.currentTime, 'State time should match current time');

    fprintf('✓ State access passed\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('✗ State access failed: %s\n', ME.message);
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