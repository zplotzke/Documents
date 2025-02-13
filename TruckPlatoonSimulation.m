classdef TruckPlatoonSimulation < handle
    % TRUCKPLATOONSIMULATION Core simulation engine for truck platoon
    %
    % Manages the complete simulation of a truck platoon including:
    % - State management for each truck
    % - Physics calculations
    % - Time stepping
    % - Data collection
    %
    % Author: zplotzke
    % Last Modified: 2025-02-13 02:09:54 UTC
    % Version: 1.0.9

    properties (SetAccess = private)
        config          % Configuration parameters
        currentTime    % Current simulation time
        timeHistory    % Array of time points
        stateHistory   % Cell array of state structures
        logger         % Logger instance
    end

    properties (Access = private)
        trucks         % Array of truck state structures
        isSimFinished % Flag indicating if simulation is complete
        rng           % Random number generator
    end

    methods
        function obj = TruckPlatoonSimulation()
            % Constructor
            % Get logger instance
            obj.logger = utils.Logger.getLogger('TruckPlatoonSim');

            % Get configuration directly
            obj.config = config.getConfig();

            % Initialize simulation
            obj.resetSimulation();
        end

        function resetSimulation(obj)
            % RESETSIMULATION Reset simulation to initial state
            obj.currentTime = 0;
            obj.timeHistory = [];
            obj.stateHistory = {};  % Initialize as empty cell array
            obj.isSimFinished = false;

            % Set random seed for reproducibility
            obj.rng = RandStream('mt19937ar', 'Seed', obj.config.simulation.random_seed);

            % Initialize trucks
            obj.initializeTrucks();

            obj.logger.info('Simulation reset completed');
        end

        function randomizeParameters(obj)
            % RANDOMIZEPARAMETERS Randomize truck parameters within bounds
            for i = 1:length(obj.trucks)
                obj.trucks(i).length = obj.rng.unifrnd(...
                    obj.config.truck.min_length, ...
                    obj.config.truck.max_length);

                obj.trucks(i).weight = obj.rng.unifrnd(...
                    obj.config.truck.min_weight, ...
                    obj.config.truck.max_weight);
            end
            obj.logger.info('Truck parameters randomized');
        end

        function state = step(obj)
            % STEP Advance simulation by one time step
            if obj.isSimFinished
                obj.logger.warning('Attempted to step finished simulation');
                state = obj.getState();
                return;
            end

            % Update time
            obj.currentTime = obj.currentTime + obj.config.simulation.time_step;

            % Calculate new states for all trucks
            obj.updateTruckStates();

            % Record history
            obj.recordState();

            % Check completion conditions
            obj.checkCompletion();

            % Return current state
            state = obj.getState();
        end

        function state = getState(obj)
            % GETSTATE Get current simulation state
            state = struct(...
                'time', obj.currentTime, ...
                'positions', obj.getTruckPositions(), ...
                'velocities', obj.getTruckVelocities(), ...
                'accelerations', obj.getTruckAccelerations(), ...
                'jerks', obj.getTruckJerks(), ...
                'isFinished', obj.isSimFinished ...
                );
        end

        function history = getCompleteState(obj)
            % GETCOMPLETESTATE Get complete simulation history
            history = struct(...
                'timeHistory', obj.timeHistory, ...
                'stateHistory', obj.stateHistory ...
                );
        end

        function finished = isFinished(obj)
            % ISFINISHED Check if simulation is complete
            finished = obj.isSimFinished;
        end
    end

    methods (Access = private)
        function initializeTrucks(obj)
            % Initialize truck states
            numTrucks = obj.config.truck.num_trucks;
            obj.trucks = struct([]);

            for i = 1:numTrucks
                obj.trucks(i).position = -(i-1) * obj.config.truck.initial_spacing;

                % Initialize velocity from config or default to 0
                if isfield(obj.config.truck, 'initial_velocity')
                    obj.trucks(i).velocity = obj.config.truck.initial_velocity;
                else
                    obj.trucks(i).velocity = 0;
                end

                % Initialize acceleration from config or default to 0
                if isfield(obj.config.truck, 'constant_acceleration')
                    obj.trucks(i).acceleration = obj.config.truck.constant_acceleration;
                else
                    obj.trucks(i).acceleration = 0;
                end

                obj.trucks(i).jerk = 0;
                obj.trucks(i).length = obj.config.truck.min_length;
                obj.trucks(i).weight = obj.config.truck.min_weight;
            end
        end

        function updateTruckStates(obj)
            % Update states of all trucks
            dt = obj.config.simulation.time_step;

            for i = 1:length(obj.trucks)
                % Update kinematics
                obj.trucks(i).position = obj.trucks(i).position + ...
                    obj.trucks(i).velocity * dt + ...
                    0.5 * obj.trucks(i).acceleration * dt^2 + ...
                    (1/6) * obj.trucks(i).jerk * dt^3;

                obj.trucks(i).velocity = obj.trucks(i).velocity + ...
                    obj.trucks(i).acceleration * dt + ...
                    0.5 * obj.trucks(i).jerk * dt^2;

                % Maintain constant acceleration if specified in config
                if isfield(obj.config.truck, 'constant_acceleration')
                    obj.trucks(i).acceleration = obj.config.truck.constant_acceleration;
                else
                    obj.trucks(i).acceleration = obj.trucks(i).acceleration + ...
                        obj.trucks(i).jerk * dt;
                end

                % Apply constraints
                obj.applyConstraints(i);
            end
        end

        function applyConstraints(obj, truckIndex)
            % Apply physical constraints to truck states
            truck = obj.trucks(truckIndex);

            % Velocity constraints
            truck.velocity = min(max(truck.velocity, 0), ...
                obj.config.truck.max_velocity);

            % Acceleration constraints (skip if constant acceleration is set)
            if ~isfield(obj.config.truck, 'constant_acceleration')
                truck.acceleration = min(max(truck.acceleration, ...
                    obj.config.truck.max_deceleration), ...
                    obj.config.truck.max_acceleration);
            end

            % Jerk constraints
            truck.jerk = min(max(truck.jerk, ...
                -obj.config.truck.max_jerk), ...
                obj.config.truck.max_jerk);

            obj.trucks(truckIndex) = truck;
        end

        function recordState(obj)
            % Record current state in history
            obj.timeHistory(end+1) = obj.currentTime;
            if isempty(obj.stateHistory)
                obj.stateHistory = {obj.getState()};
            else
                obj.stateHistory{end+1} = obj.getState();
            end
        end

        function checkCompletion(obj)
            % Check if simulation should end
            leadPosition = obj.trucks(1).position;

            if leadPosition >= obj.config.simulation.distance_goal
                obj.isSimFinished = true;
                obj.logger.info('Simulation completed - Distance goal reached');
            elseif obj.currentTime >= obj.config.simulation.duration
                obj.isSimFinished = true;
                obj.logger.warning('Simulation completed - Time limit reached');
            end
        end

        % Getter methods for truck state arrays
        function pos = getTruckPositions(obj)
            pos = [obj.trucks.position];
        end

        function vel = getTruckVelocities(obj)
            vel = [obj.trucks.velocity];
        end

        function acc = getTruckAccelerations(obj)
            acc = [obj.trucks.acceleration];
        end

        function jer = getTruckJerks(obj)
            jer = [obj.trucks.jerk];
        end
    end
end