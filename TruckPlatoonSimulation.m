classdef TruckPlatoonSimulation < handle
    % TRUCKPLATOONSIMULATION Simulator for truck platoon dynamics
    %
    % Simulates truck platoon behavior with support for both safe and unsafe
    % scenarios to generate comprehensive training data.
    %
    % Author: zplotzke
    % Last Modified: 2025-02-19 20:02:13 UTC
    % Version: 1.2.0

    properties (Access = private)
        config          % Configuration settings
        logger         % Logger instance
        state          % Current simulation state
        mode           % Simulation mode
        time           % Current simulation time
        violationProbability = 0.3  % 30% chance of generating unsafe parameters
    end

    methods
        function obj = TruckPlatoonSimulation()
            obj.config = config.getConfig();
            obj.logger = utils.Logger.getLogger('TruckPlatoonSim');
            obj.reset();
            obj.logger.info('Simulation reset completed');
        end

        function reset(obj)
            % RESET Reset simulation to initial state
            obj.time = 0;
            obj.mode = 'stopped';

            % Initialize state structure
            obj.state = struct(...
                'positions', zeros(1, obj.config.truck.num_trucks), ...
                'velocities', zeros(1, obj.config.truck.num_trucks), ...
                'accelerations', zeros(1, obj.config.truck.num_trucks), ...
                'jerks', zeros(1, obj.config.truck.num_trucks), ...
                'time', 0 ...
                );

            % Set initial positions with proper spacing
            spacing = obj.config.truck.initial_spacing;
            for i = 1:obj.config.truck.num_trucks
                obj.state.positions(i) = (i-1) * spacing;
            end
        end

        function state = getState(obj)
            % GETSTATE Get current simulation state
            state = obj.state;
        end

        function setState(obj, state)
            % SETSTATE Set simulation state
            obj.state = state;
        end

        function startSimulation(obj, mode)
            % STARTSIMULATION Start simulation in specified mode
            obj.mode = mode;
            obj.logger.info('Starting simulation in %s mode', mode);
        end

        function state = step(obj)
            % STEP Advance simulation by one time step
            dt = obj.config.simulation.time_step;
            obj.time = obj.time + dt;

            % Update state (simplified for testing)
            obj.state.time = obj.time;
            state = obj.state;
        end

        function randomizeParameters(obj)
            % RANDOMIZEPARAMETERS Randomize simulation parameters for training
            % Generates both safe and unsafe scenarios for better training data
            num_trucks = obj.config.truck.num_trucks;

            % Decide if this simulation should have safety violations
            generate_unsafe = rand() < obj.violationProbability;

            if generate_unsafe
                % Choose a random violation type
                violation_types = {'distance', 'speed', 'acceleration', 'mixed'};
                violation_type = violation_types{randi(length(violation_types))};

                obj.logger.info('Generating unsafe scenario: %s violation', violation_type);

                switch violation_type
                    case 'distance'
                        obj.generateUnsafeDistances();
                    case 'speed'
                        obj.generateUnsafeSpeeds();
                    case 'acceleration'
                        obj.generateUnsafeAccelerations();
                    case 'mixed'
                        obj.generateMixedViolations();
                end
            else
                % Generate safe parameters
                obj.logger.info('Generating safe scenario');
                obj.generateSafeParameters();
            end

            obj.logger.debug('Parameters randomized for training (Safe: %d)', ~generate_unsafe);
        end

        function generateSafeParameters(obj)
            % Generate completely safe parameters
            num_trucks = obj.config.truck.num_trucks;
            min_distance = obj.config.safety.min_safety_distance;

            % Safe positions with proper spacing
            for i = 2:num_trucks
                safe_space = min_distance * (2 + rand());  % 2-3x minimum distance
                obj.state.positions(i) = obj.state.positions(i-1) + safe_space;
            end

            % Safe velocities (60-80% of max speed)
            max_vel = obj.config.truck.max_velocity;
            for i = 1:num_trucks
                obj.state.velocities(i) = max_vel * (0.6 + 0.2 * rand());
            end

            % Safe accelerations (0-30% of max)
            max_accel = obj.config.truck.max_acceleration;
            obj.state.accelerations = rand(1, num_trucks) * 0.3 * max_accel;

            % Safe jerks (0-20% of max)
            max_jerk = obj.config.truck.max_jerk;
            obj.state.jerks = rand(1, num_trucks) * 0.2 * max_jerk;
        end

        function generateUnsafeDistances(obj)
            % Generate scenarios with unsafe distances
            num_trucks = obj.config.truck.num_trucks;
            min_distance = obj.config.safety.min_safety_distance;

            % Choose random truck pair for unsafe distance
            unsafe_idx = randi(num_trucks-1);

            % Set positions with one unsafe gap
            for i = 2:num_trucks
                if i == unsafe_idx + 1
                    % Create unsafe gap (30-70% of minimum safe distance)
                    unsafe_space = min_distance * (0.3 + 0.4 * rand());
                    obj.state.positions(i) = obj.state.positions(i-1) + unsafe_space;
                else
                    % Normal safe spacing for other trucks
                    safe_space = min_distance * (2 + rand());
                    obj.state.positions(i) = obj.state.positions(i-1) + safe_space;
                end
            end

            % Use safe velocities and accelerations
            obj.generateSafeParameters();

            obj.logger.debug('Generated unsafe distance between trucks %d and %d', ...
                unsafe_idx, unsafe_idx + 1);
        end

        function generateUnsafeSpeeds(obj)
            % Generate scenarios with unsafe speeds
            num_trucks = obj.config.truck.num_trucks;
            max_vel = obj.config.truck.max_velocity;

            % Choose random truck for speed violation
            unsafe_idx = randi(num_trucks);

            % Set speeds with one unsafe value
            for i = 1:num_trucks
                if i == unsafe_idx
                    % Unsafe speed (110-130% of max)
                    obj.state.velocities(i) = max_vel * (1.1 + 0.2 * rand());
                else
                    % Safe speeds for other trucks
                    obj.state.velocities(i) = max_vel * (0.6 + 0.2 * rand());
                end
            end

            % Use safe positions and accelerations
            obj.generateSafeParameters();
            obj.logger.debug('Generated unsafe speed for truck %d', unsafe_idx);
        end

        function generateUnsafeAccelerations(obj)
            % Generate scenarios with unsafe accelerations
            num_trucks = obj.config.truck.num_trucks;
            max_accel = obj.config.truck.max_acceleration;
            max_decel = abs(obj.config.truck.max_deceleration);

            % Choose random truck for acceleration violation
            unsafe_idx = randi(num_trucks);

            % Set accelerations with one unsafe value
            for i = 1:num_trucks
                if i == unsafe_idx
                    % Randomly choose between unsafe acceleration or deceleration
                    if rand() < 0.5
                        obj.state.accelerations(i) = max_accel * (1.2 + 0.3 * rand());
                    else
                        obj.state.accelerations(i) = -max_decel * (1.2 + 0.3 * rand());
                    end
                else
                    % Safe accelerations for other trucks
                    obj.state.accelerations(i) = max_accel * (0.3 * rand());
                end
            end

            % Use safe positions and velocities
            obj.generateSafeParameters();
            obj.logger.debug('Generated unsafe acceleration for truck %d', unsafe_idx);
        end

        function generateMixedViolations(obj)
            % Generate scenarios with multiple types of violations
            num_trucks = obj.config.truck.num_trucks;

            % Randomly choose two different violation types
            violations = {'distance', 'speed', 'acceleration'};
            idx = randperm(3, 2);

            % Apply first violation
            switch violations{idx(1)}
                case 'distance'
                    obj.generateUnsafeDistances();
                case 'speed'
                    obj.generateUnsafeSpeeds();
                case 'acceleration'
                    obj.generateUnsafeAccelerations();
            end

            % Store current state
            temp_state = obj.state;

            % Apply second violation and merge with first
            switch violations{idx(2)}
                case 'distance'
                    obj.generateUnsafeDistances();
                case 'speed'
                    obj.generateUnsafeSpeeds();
                case 'acceleration'
                    obj.generateUnsafeAccelerations();
            end

            % Merge violations (keep unsafe parameters from both)
            for i = 1:num_trucks
                if abs(obj.state.velocities(i)) > obj.config.truck.max_velocity
                    temp_state.velocities(i) = obj.state.velocities(i);
                end
                if abs(obj.state.accelerations(i)) > obj.config.truck.max_acceleration
                    temp_state.accelerations(i) = obj.state.accelerations(i);
                end
            end
            obj.state = temp_state;

            obj.logger.debug('Generated mixed violations: %s and %s', ...
                violations{idx(1)}, violations{idx(2)});
        end

        function finished = isFinished(obj)
            % ISFINISHED Check if simulation has finished
            finished = obj.time >= obj.config.simulation.max_simulation_time;
        end
    end
end