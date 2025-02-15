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
    % Last Modified: 2025-02-15 05:23:29 UTC
    % Version: 1.2.0

    properties (SetAccess = private)
        config          % Simulation configuration
        currentTime    % Current simulation time
        timeHistory    % Array of time points
        stateHistory   % Cell array of state structures
        logger         % Logger instance
        simulationType % Current simulation type (training/validation/final)
    end

    properties (Access = private)
        trucks         % Array of truck state structures
        isSimFinished % Flag indicating if simulation is complete
        rng           % Random number generator
        isRunning     % Flag indicating if simulation is running
        isPaused      % Flag indicating if simulation is paused
    end

    methods
        function obj = TruckPlatoonSimulation()
            % Constructor
            % Get logger instance
            obj.logger = utils.Logger.getLogger('TruckPlatoonSim');

            % Get configuration directly
            obj.config = config.getConfig();

            % Initialize simulation state flags
            obj.simulationType = '';
            obj.isRunning = false;
            obj.isPaused = false;

            % Initialize simulation
            obj.resetSimulation();
        end

        function resetSimulation(obj)
            % RESETSIMULATION Reset simulation to initial state
            obj.currentTime = 0;

            % Initialize empty arrays
            obj.timeHistory = [];
            obj.stateHistory = {};

            obj.isSimFinished = false;
            obj.isRunning = false;
            obj.isPaused = false;
            obj.simulationType = '';

            % Set random seed for reproducibility
            obj.rng = RandStream('mt19937ar', 'Seed', obj.config.simulation.random_seed);

            % Initialize trucks and ensure proper spacing
            obj.initializeTrucks();
            obj.adjustSpacing();

            obj.logger.info('Simulation reset completed');
        end

        function startSimulation(obj, simType)
            % STARTSIMULATION Start simulation with specified type
            %   Valid types: 'training', 'validation', 'final'

            if ~ischar(simType) && ~isstring(simType)
                error('TruckPlatoonSim:InvalidType', 'Simulation type must be a string');
            end

            validTypes = {'training', 'validation', 'final'};
            if ~ismember(simType, validTypes)
                error('TruckPlatoonSim:InvalidType', ...
                    'Invalid simulation type. Must be one of: %s', ...
                    strjoin(validTypes, ', '));
            end

            % Ensure proper spacing before starting
            obj.adjustSpacing();

            if ~obj.validateState()
                error('TruckPlatoonSim:InvalidState', ...
                    'Cannot start simulation with invalid initial state');
            end

            obj.simulationType = simType;
            obj.isRunning = true;
            obj.isPaused = false;
            obj.logger.info('Starting simulation in %s mode', simType);
        end

        function pauseSimulation(obj)
            % PAUSESIMULATION Pause the running simulation
            if obj.isRunning
                obj.isPaused = true;
                obj.logger.info('Simulation paused');
            end
        end

        function resumeSimulation(obj)
            % RESUMESIMULATION Resume a paused simulation
            if obj.isRunning && obj.isPaused
                obj.isPaused = false;
                obj.logger.info('Simulation resumed');
            end
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

            % Ensure proper spacing after randomization
            obj.adjustSpacing();

            obj.logger.info('Truck parameters randomized');
        end

        function state = step(obj)
            % STEP Advance simulation by one time step
            if ~obj.isRunning || obj.isPaused || obj.isSimFinished
                state = obj.getState();
                return;
            end

            % Update time
            obj.currentTime = obj.currentTime + obj.config.simulation.time_step;

            % Calculate new states for all trucks
            obj.updateTruckStates();

            % Ensure safe spacing
            obj.adjustSpacing();

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

        function valid = validateState(obj)
            % VALIDATESTATE Validate current simulation state
            %   Returns true if all state parameters are within valid bounds
            valid = true;

            try
                % Check if trucks exist and have valid properties
                if ~isfield(obj.trucks, 'length') || length(obj.trucks) ~= obj.config.truck.num_trucks
                    obj.logger.warning('Invalid truck configuration: incorrect number of trucks or missing length field');
                    valid = false;
                    return;
                end

                % Get current state for validation
                positions = obj.getTruckPositions();
                velocities = obj.getTruckVelocities();
                accelerations = obj.getTruckAccelerations();
                jerks = obj.getTruckJerks();

                % Validate truck properties
                for i = 1:length(obj.trucks)
                    % Check truck dimensions
                    if obj.trucks(i).length < obj.config.truck.min_length || ...
                            obj.trucks(i).length > obj.config.truck.max_length
                        obj.logger.warning('Truck %d has invalid length: %.2f', i, obj.trucks(i).length);
                        valid = false;
                        return;
                    end

                    % Check truck weight
                    if obj.trucks(i).weight < obj.config.truck.min_weight || ...
                            obj.trucks(i).weight > obj.config.truck.max_weight
                        obj.logger.warning('Truck %d has invalid weight: %.2f', i, obj.trucks(i).weight);
                        valid = false;
                        return;
                    end

                    % Check velocity bounds
                    if abs(velocities(i)) > obj.config.truck.max_velocity
                        obj.logger.warning('Truck %d exceeds velocity limits: %.2f', i, velocities(i));
                        valid = false;
                        return;
                    end

                    % Check acceleration bounds
                    if accelerations(i) > obj.config.truck.max_acceleration || ...
                            accelerations(i) < obj.config.truck.max_deceleration
                        obj.logger.warning('Truck %d exceeds acceleration limits: %.2f', i, accelerations(i));
                        valid = false;
                        return;
                    end

                    % Check jerk bounds
                    if abs(jerks(i)) > obj.config.truck.max_jerk
                        obj.logger.warning('Truck %d exceeds jerk limits: %.2f', i, jerks(i));
                        valid = false;
                        return;
                    end
                end

                % Validate spacing between trucks (front to back)
                for i = 1:(length(positions) - 1)
                    spacing = positions(i) - positions(i+1) - obj.trucks(i).length;
                    if spacing < obj.config.truck.min_safe_distance
                        obj.logger.warning('Unsafe spacing between trucks %d and %d: %.2f', i, i+1, spacing);
                        valid = false;
                        return;
                    end
                end

                % Validate simulation state consistency
                if ~obj.isRunning && ~obj.isSimFinished && ~isempty(obj.simulationType)
                    obj.logger.warning('Invalid simulation state: not running and not finished');
                    valid = false;
                    return;
                end

                if obj.currentTime < 0 || obj.currentTime > obj.config.simulation.duration
                    obj.logger.warning('Invalid simulation time: %.2f', obj.currentTime);
                    valid = false;
                    return;
                end

            catch ME
                obj.logger.error('Error in validateState: %s', ME.message);
                valid = false;
            end
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
            % Initialize truck states with proper spacing
            numTrucks = obj.config.truck.num_trucks;

            % Pre-allocate structure array with all fields
            emptyTruck = struct(...
                'position', 0, ...
                'velocity', 0, ...
                'acceleration', 0, ...
                'jerk', 0, ...
                'length', 0, ...
                'weight', 0 ...
                );
            obj.trucks = repmat(emptyTruck, [1, numTrucks]);

            % Calculate total required spacing
            minSpacing = obj.config.truck.min_safe_distance + obj.config.truck.max_length;

            % Initialize from back to front to maintain proper spacing
            for i = 1:numTrucks
                % Set initial position with proper spacing
                obj.trucks(i).position = -(i-1) * (minSpacing + obj.config.truck.initial_spacing);

                % Set other properties
                obj.trucks(i).velocity = obj.config.truck.initial_velocity;
                obj.trucks(i).acceleration = obj.config.truck.constant_acceleration;
                obj.trucks(i).jerk = 0;
                obj.trucks(i).length = obj.config.truck.max_length;  % Use max length for safety
                obj.trucks(i).weight = obj.config.truck.min_weight;
            end

            % Verify initial spacing
            if ~obj.validateState()
                obj.logger.warning('Initial truck configuration may be unsafe');
            end
        end

        function adjustSpacing(obj)
            % Adjust spacing between trucks to ensure safety
            positions = obj.getTruckPositions();
            minSpacing = obj.config.truck.min_safe_distance;

            for i = 2:length(positions)
                requiredSpace = minSpacing + obj.trucks(i-1).length;
                currentSpace = positions(i-1) - positions(i) - obj.trucks(i-1).length;

                if currentSpace < requiredSpace
                    % Move trailing truck back to maintain safe distance
                    obj.trucks(i).position = positions(i-1) - requiredSpace - obj.trucks(i-1).length;
                end
            end
        end

        function updateTruckStates(obj)
            % Update states of all trucks
            dt = obj.config.simulation.time_step;

            for i = 1:length(obj.trucks)
                % Update kinematics with jerk consideration
                obj.trucks(i).position = obj.trucks(i).position + ...
                    obj.trucks(i).velocity * dt + ...
                    0.5 * obj.trucks(i).acceleration * dt^2 + ...
                    (1/6) * obj.trucks(i).jerk * dt^3;

                obj.trucks(i).velocity = obj.trucks(i).velocity + ...
                    obj.trucks(i).acceleration * dt + ...
                    0.5 * obj.trucks(i).jerk * dt^2;

                if isfield(obj.config.truck, 'constant_acceleration')
                    obj.trucks(i).acceleration = obj.config.truck.constant_acceleration;
                else
                    obj.trucks(i).acceleration = obj.trucks(i).acceleration + ...
                        obj.trucks(i).jerk * dt;
                end

                % Apply constraints
                obj.applyConstraints(i);
            end

            % Ensure safe spacing after state update
            obj.adjustSpacing();
        end

        function applyConstraints(obj, truckIndex)
            % Apply physical constraints to truck states
            truck = obj.trucks(truckIndex);

            % Velocity constraints
            truck.velocity = min(max(truck.velocity, 0), ...
                obj.config.truck.max_velocity);

            % Acceleration constraints
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
            % RECORDSTATE Record current state in history
            % Simply append current state to history arrays

            try
                % Get current state
                currentState = obj.getState();

                % Simply append to arrays
                if isempty(obj.timeHistory)
                    obj.timeHistory = currentState.time;
                    obj.stateHistory = {currentState};
                else
                    obj.timeHistory(end+1) = currentState.time;
                    obj.stateHistory{end+1} = currentState;
                end

            catch ME
                obj.logger.error('Error in recordState: %s', ME.message);
                rethrow(ME);
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