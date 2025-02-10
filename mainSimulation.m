classdef mainSimulation < handle
    % MAINSIMULATION Class for truck platoon simulation
    %
    % This class handles the core simulation logic for a platoon of trucks,
    % including dynamics, safety constraints, and logging.
    %
    % Properties:
    %   config              - Configuration structure from getConfig
    %   currentTime         - Current simulation time
    %   timeHistory        - History of simulation states
    %
    % Author: zplotzke
    % Last Modified: 2025-02-08 17:06:05 UTC
    % Version: 1.0.1

    properties (SetAccess = private)
        config          % Configuration structure from getConfig
        currentTime    % Current simulation time
        timeHistory    % History of simulation states
    end

    properties (Access = protected)
        truckPositions     % Array of truck positions
        truckVelocities    % Array of truck velocities
        truckAccelerations % Array of truck accelerations
        truckLengths       % Array of truck lengths
        truckWeights       % Array of truck weights
        isInitialized      % Flag to track initialization status
    end

    methods
        function obj = mainSimulation()
            % Constructor: Initialize simulation with configuration
            obj.config = getConfig();
            obj.currentTime = 0;
            obj.isInitialized = false;
            obj.initializeSimulation();
        end

        function reset(obj)
            % Reset simulation to initial state
            obj.currentTime = 0;
            obj.initializeSimulation();
        end

        function success = step(obj)
            % Perform one simulation timestep
            % Returns:
            %   success - boolean indicating if step completed successfully

            if ~obj.isInitialized
                error('Simulation:NotInitialized', ...
                    'Simulation must be initialized before stepping');
            end

            try
                dt = 1/obj.config.simulation.frame_rate;
                obj.updateTruckDynamics(dt);
                obj.checkSafetyConstraints();
                obj.updateTimeHistory();
                obj.currentTime = obj.currentTime + dt;
                success = true;
            catch ME
                success = false;
                rethrow(ME);
            end
        end

        function state = getState(obj)
            % Get current simulation state
            % Returns:
            %   state - Structure containing current simulation state

            state = struct(...
                'time', obj.currentTime, ...
                'positions', obj.truckPositions, ...
                'velocities', obj.truckVelocities, ...
                'lengths', obj.truckLengths, ...
                'weights', obj.truckWeights, ...
                'isValid', obj.checkSafetyConstraints());
        end

        function positions = getTruckPositions(obj)
            % Get current truck positions
            positions = obj.truckPositions;
        end

        function velocities = getTruckVelocities(obj)
            % Get current truck velocities
            velocities = obj.truckVelocities;
        end
    end

    methods (Access = private)
        function initializeSimulation(obj)
            % Initialize or reinitialize simulation components
            obj.initializeTrucks();
            obj.initializeTimeHistory();
            obj.isInitialized = true;
        end

        function initializeTrucks(obj)
            % Initialize truck arrays with configuration parameters
            numTrucks = obj.config.truck.num_trucks;

            % Initialize arrays
            obj.truckPositions = zeros(1, numTrucks);
            obj.truckVelocities = ones(1, numTrucks) * obj.config.truck.initial_speed;
            obj.truckAccelerations = zeros(1, numTrucks);
            obj.truckLengths = obj.config.truck.truck_lengths(:)';
            obj.truckWeights = obj.config.truck.truck_weights(:)';

            % Calculate total platoon length for centering
            total_platoon_length = sum(obj.truckLengths) + ...
                (numTrucks - 1) * obj.config.truck.desired_gap;

            % Start at position 200 for better visibility
            view_center = 200;
            start_position = view_center + total_platoon_length/2;

            % Set initial positions with proper spacing
            obj.truckPositions(1) = start_position;
            for i = 2:numTrucks
                obj.truckPositions(i) = obj.truckPositions(i-1) - ...
                    (obj.truckLengths(i-1) + obj.config.truck.desired_gap);
            end
        end

        function initializeTimeHistory(obj)
            % Initialize time history storage with initial state
            obj.timeHistory = struct(...
                'times', obj.currentTime, ...
                'positions', obj.truckPositions(:), ...
                'velocities', obj.truckVelocities(:), ...
                'accelerations', obj.truckAccelerations(:));
        end

        function updateTruckDynamics(obj, dt)
            % Update positions and velocities of all trucks
            % Using basic kinematic equations:
            % v = v0 + a*t
            % x = x0 + v0*t + 0.5*a*t^2

            % Update velocities
            obj.truckVelocities = obj.truckVelocities + ...
                obj.truckAccelerations * dt;

            % Update positions
            obj.truckPositions = obj.truckPositions + ...
                obj.truckVelocities * dt + ...
                0.5 * obj.truckAccelerations * dt^2;

            % Apply velocity constraints
            obj.truckVelocities = min(max(obj.truckVelocities, 0), ...
                obj.config.truck.initial_speed + ...
                obj.config.truck.max_relative_velocity);
        end

        function isValid = checkSafetyConstraints(obj)
            % Verify safety constraints are maintained
            % Returns:
            %   isValid - boolean indicating if all constraints are satisfied

            isValid = true;

            % Check minimum distances between trucks
            for i = 1:length(obj.truckPositions)-1
                distance = obj.truckPositions(i) - ...
                    obj.truckPositions(i+1) - ...
                    obj.truckLengths(i);

                if distance < obj.config.safety.min_safe_distance
                    isValid = false;
                    break;
                end
            end

            % Check velocity constraints
            if any(abs(obj.truckVelocities) > ...
                    obj.config.truck.initial_speed + ...
                    obj.config.truck.max_relative_velocity)
                isValid = false;
            end
        end

        function updateTimeHistory(obj)
            % Update time history with current state
            % Append current time
            obj.timeHistory.times(end+1) = obj.currentTime;

            % Append current positions as a new column
            obj.timeHistory.positions = [obj.timeHistory.positions, obj.truckPositions(:)];

            % Append current velocities as a new column
            obj.timeHistory.velocities = [obj.timeHistory.velocities, obj.truckVelocities(:)];

            % Append current accelerations as a new column
            obj.timeHistory.accelerations = [obj.timeHistory.accelerations, obj.truckAccelerations(:)];
        end
    end
end