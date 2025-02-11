function runPlatoonSimulation()
% RUNPLATOONSIMULATION Main entry point for truck platoon simulation
%
% This function orchestrates the complete truck platoon simulation including:
% - Training phase with 10 random simulations
% - LSTM network training
% - Final one-mile journey simulation with visualization
%
% Author: zplotzke
% Last Modified: 2025-02-11 15:07:37 UTC
% Version: 1.0.0

try
    % Get logger instance
    logger = utils.Logger.getLogger('Main');
    logger.info('Starting truck platoon simulation');

    % Load configuration
    config = config.getConfig();

    % Initialize components
    visualizer = viz.PlatoonVisualizer(config);
    safety_monitor = core.SafetyMonitor(config);
    trainer = core.PlatoonTrainer(config);

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

    % Initialize simulation with random parameters
    sim = core.TruckPlatoonSimulation(config);
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

function runFinalSimulation(config, trainer, safety_monitor, visualizer, logger)
% Run final simulation with visualization
sim = core.TruckPlatoonSimulation(config);

% Initialize visualization
visualizer.initialize();

while ~sim.isFinished()
    % Get current state
    state = sim.getState();

    % Get predictions for next state
    predictions = ml.predictNextState(trainer.getNetwork(), state);

    % Update visualization
    visualizer.update(state, predictions);

    % Check safety conditions
    [is_safe, violations] = safety_monitor.checkSafetyConditions(...
        state.positions, ...
        state.velocities, ...
        state.accelerations, ...
        state.jerks);

    if ~is_safe
        safety_monitor.logViolations(violations, state.time);
        visualizer.showWarnings(violations);
    end

    % Step simulation
    sim.step();

    % Add small delay for visualization
    pause(1/config.simulation.frame_rate);
end

% Show final results
visualizer.showFinalResults(sim.getCompleteState());
logger.info('Final simulation completed - Distance traveled: %.2f meters', ...
    max(state.positions));
end