function runTruckPlatoonSimulation()
% RUNTRUCKPLATOONSIMULATION Main entry point for truck platoon simulation
%
% Author: zplotzke
% Last Modified: 2025-02-11 04:33:50 UTC

% Get logger instance
logger = Logger.getLogger('TruckPlatoonSim');

try
    % Load configuration
    config = getConfig();

    % Log simulation start
    logger.info('Starting truck platoon simulation');

    % Initialize simulation with config
    sim = MainSimulation(config);  % Updated class name

    % Main simulation loop
    while ~sim.isFinished()
        % Step simulation forward
        sim.step();
    end

    % Log simulation completion
    logger.info('Simulation completed successfully');

catch ME
    % Log error and re-throw
    logger.error('Simulation failed: %s', ME.message);
    rethrow(ME);
end
end