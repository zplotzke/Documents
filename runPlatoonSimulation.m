function runPlatoonSimulation()
% RUNPLATOONSIMULATION Main entry point for truck platoon simulation
%
% This function orchestrates the complete truck platoon simulation including:
% - Training phase with 10 random simulations
% - LSTM network training
% - Final one-mile journey simulation with visualization
%
% Author: zplotzke
% Last Modified: 2025-02-13 02:13:13 UTC
% Version: 1.0.2

try
    % Get logger instance
    logger = utils.Logger.getLogger('Main');
    logger.info('Starting truck platoon simulation');

    % Get configuration
    config = config.getConfig();

    % Initialize components without passing config
    visualizer = viz.PlatoonVisualizer();
    safety_monitor = core.SafetyMonitor();
    trainer = core.PlatoonTrainer();

    % Phase 1: Run 10 random training simulations
    logger.info('Starting training data collection phase...');
    runTrainingSimulations(config, trainer, safety_monitor, logger);

    % Phase 2: Train LSTM network
    logger.info('Starting LSTM network training phase...');
    trainer.trainNetwork();

    % Phase 3: Run final simulation with predictions
    logger.info('Starting final simulation phase...');
    runFinalSimulation(config, trainer, safety_monitor, visualizer, logger);

    logger.info('Simulation completed successfully');

catch ME
    if exist('logger', 'var')
        logger.error('Simulation failed: %s', ME.message);
        logger.error('Stack trace: %s', getReport(ME));
    else
        fprintf(2, 'Fatal error before logger initialization: %s\n', ME.message);
        fprintf(2, 'Stack trace:\n%s\n', getReport(ME));
    end
    rethrow(ME);
end
end

function runTrainingSimulations(config, trainer, safety_monitor, logger)
% Run training simulations to collect data
for i = 1:config.simulation.num_random_simulations
    logger.info('Training simulation %d/%d', i, config.simulation.num_random_simulations);

    % Initialize simulation
    sim = core.TruckPlatoonSimulation();
    sim.randomizeParameters();

    % Run simulation and collect data
    while ~sim.isFinished()
        state = sim.step();
        trainer.collectSimulationData(state);

        % Check safety conditions
        [is_safe, violations] = safety_monitor.checkSafetyConditions(...
            state.positions, ...
            state.velocities, ...
            state.accelerations, ...
            state.jerks);

        if ~is_safe
            logViolations(safety_monitor, violations, state.time, logger);
        end
    end

    logger.info('Training simulation %d completed', i);

    % Log statistics for this simulation
    logSimulationStats(sim, i, logger);
end
end

function runFinalSimulation(config, trainer, safety_monitor, visualizer, logger)
% Run final simulation with visualization
sim = core.TruckPlatoonSimulation();

% Initialize visualization
visualizer.initialize();

try
    lastVisualizationTime = 0;
    visualizationInterval = 1 / config.visualization.plot_refresh_rate;

    while ~sim.isFinished()
        % Get current state
        state = sim.getState();

        % Get predictions for next state if network is trained
        if trainer.IsNetworkTrained
            predictions = ml.predictNextState(trainer.getNetwork(), state);
        else
            predictions = [];
        end

        % Update visualization at specified refresh rate
        if (state.time - lastVisualizationTime) >= visualizationInterval
            visualizer.update(state, predictions);
            lastVisualizationTime = state.time;
        end

        % Check safety conditions
        [is_safe, violations] = safety_monitor.checkSafetyConditions(...
            state.positions, ...
            state.velocities, ...
            state.accelerations, ...
            state.jerks);

        if ~is_safe
            logViolations(safety_monitor, violations, state.time, logger);
            visualizer.showWarnings(violations);
        end

        % Step simulation
        sim.step();
    end

    % Show final results
    finalState = sim.getCompleteState();
    visualizer.showFinalResults(finalState);
    logFinalResults(finalState, logger);

catch ME
    logger.error('Final simulation failed: %s', ME.message);
    rethrow(ME);
end
end

function logViolations(safety_monitor, violations, time, logger)
% Log safety violations with detailed information
for i = 1:length(violations)
    violation = violations{i};
    logger.warning('Time %.2fs - %s: %s', ...
        time, ...
        violation.type, ...
        violation.message);

    % Log detailed data based on violation type
    switch violation.type
        case 'COLLISION'
            logger.warning('  Distance: %.2fm, Relative Velocity: %.2fm/s', ...
                violation.data.distance, ...
                violation.data.relative_velocity);
        case 'DISTANCE'
            logger.warning('  Current: %.2fm, Required: %.2fm', ...
                violation.data.distance, ...
                violation.data.min_required);
        case 'SPEED'
            logger.warning('  Speed: %.2fm/s, Bounds: [%.2f, %.2f]', ...
                violation.data.speed, ...
                violation.data.bounds(1), ...
                violation.data.bounds(2));
        case 'EMERGENCY_BRAKE'
            logger.warning('  Deceleration: %.2fm/s², Threshold: %.2fm/s²', ...
                violation.data.deceleration, ...
                violation.data.threshold);
    end
end
end

function logSimulationStats(sim, simIndex, logger)
% Log statistics for individual training simulations
state = sim.getCompleteState();
finalState = state.stateHistory{end};

logger.info('Training Simulation %d Statistics:', simIndex);
logger.info('  Duration: %.2f seconds', finalState.time);
logger.info('  Distance Traveled: %.2f meters', max(finalState.positions));
logger.info('  Average Speed: %.2f m/s', ...
    max(finalState.positions) / finalState.time);
logger.info('  Max Speed: %.2f m/s', max([state.stateHistory{:}.velocities]));
end

function logFinalResults(finalState, logger)
% Log comprehensive final simulation results
lastState = finalState.stateHistory{end};

logger.info('Final Simulation Results:');
logger.info('  Total Time: %.2f seconds', lastState.time);
logger.info('  Total Distance: %.2f meters', max(lastState.positions));
logger.info('  Average Speed: %.2f m/s', ...
    max(lastState.positions) / lastState.time);

% Calculate efficiency metrics
velocities = [finalState.stateHistory{:}.velocities];
accelerations = [finalState.stateHistory{:}.accelerations];
jerks = [finalState.stateHistory{:}.jerks];

logger.info('Performance Metrics:');
logger.info('  Max Speed: %.2f m/s', max(velocities(:)));
logger.info('  Max Acceleration: %.2f m/s²', max(abs(accelerations(:))));
logger.info('  RMS Jerk: %.2f m/s³', sqrt(mean(jerks(:).^2)));
end