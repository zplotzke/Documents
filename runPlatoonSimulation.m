function runPlatoonSimulation()
% RUNPLATOONSIMULATION Main entry point for truck platoon simulation
%
% This function orchestrates the complete truck platoon simulation including:
% - Training phase with 10 random simulations
% - LSTM network training
% - Final one-mile journey simulation with visualization
%
% Author: zplotzke
% Last Modified: 2025-02-13 03:13:10 UTC
% Version: 1.0.8

try
    % Get logger instance
    logger = utils.Logger.getLogger('Main');
    logger.info('Starting truck platoon simulation');

    % Get configuration
    configData = config.getConfig();

    % Initialize components
    % visualizer = viz.PlatoonVisualizer();  % Temporarily disabled
    safety_monitor = core.SafetyMonitor();
    trainer = core.PlatoonTrainer();

    % Phase 1: Run 10 random training simulations
    logger.info('Starting training data collection phase...');
    runTrainingSimulations(configData, trainer, safety_monitor, logger);  % Added configData as first parameter

    % Phase 2: Train LSTM network
    logger.info('Starting LSTM network training phase...');
    trainer.trainNetwork();

    % Phase 3: Run final simulation without visualization
    logger.info('Starting final simulation phase...');
    runFinalSimulation(configData, trainer, safety_monitor, logger);  % Added configData as first parameter

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

function runTrainingSimulations(configData, trainer, safety_monitor, logger)
% Run training simulations to collect data
for i = 1:configData.simulation.num_random_simulations  % Using configData here
    logger.info('Training simulation %d/%d', i, configData.simulation.num_random_simulations);

    % Initialize simulation with random parameters
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
            safety_monitor.logViolations(violations, state.time);
        end
    end

    logger.info('Training simulation %d completed', i);
end
end

function runFinalSimulation(configData, trainer, safety_monitor, logger)
% Run final simulation without visualization
sim = core.TruckPlatoonSimulation();

while ~sim.isFinished()
    % Get current state
    state = sim.getState();

    % Get predictions for next state
    predictions = ml.predictNextState(trainer.getNetwork(), state);

    % Check safety conditions
    [is_safe, violations] = safety_monitor.checkSafetyConditions(...
        state.positions, ...
        state.velocities, ...
        state.accelerations, ...
        state.jerks);

    if ~is_safe
        safety_monitor.logViolations(violations, state.time);
    end

    % Step simulation
    sim.step();
end

% Show final results
logger.info('Final simulation completed - Distance traveled: %.2f meters', ...
    max(state.positions));
end