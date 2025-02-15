classdef SafetyMonitor < handle
    % SAFETYMONITOR Monitor safety conditions for truck platoon
    %
    % Author: zplotzke
    % Last Modified: 2025-02-15 17:11:27 UTC
    % Version: 1.0.5

    properties (Access = private)
        simulation   % Reference to TruckPlatoonSimulation instance
        config      % Configuration structure
        logger      % Logger instance
        lastWarningTime % Time of last warning (in seconds)
        WARNING_INTERVAL = 1.0 % Fixed warning interval in seconds
    end

    methods
        function obj = SafetyMonitor()
            % Constructor
            % Initialize monitor with default configuration

            % Load configuration
            obj.config = config.getConfig();

            % Initialize logger
            obj.logger = utils.Logger.getLogger('SafetyMonitor');
            obj.lastWarningTime = 0;

            obj.logger.info('Safety monitor initialized');
        end

        function setSimulation(obj, simulation)
            % Set simulation instance to monitor
            obj.simulation = simulation;
        end

        function warnings = checkSafety(obj)
            % Check all safety conditions and return warnings
            warnings = struct('level', [], 'message', []);

            % Check if simulation is attached
            if isempty(obj.simulation)
                warnings.level = 'ERROR';
                warnings.message = 'No simulation attached to monitor';
                obj.logWarning(warnings);
                return;
            end

            % Get current state
            state = obj.simulation.getState();

            % Check spacing between vehicles
            positions = state.positions;
            minSafeDistance = obj.config.truck.min_safe_distance;

            for i = 1:(length(positions)-1)
                spacing = positions(i+1) - positions(i);
                if spacing < minSafeDistance
                    warnings.level = 'WARNING';
                    warnings.message = sprintf('Unsafe spacing between trucks %d and %d: %.2f m (min: %.2f m)', ...
                        i, i+1, spacing, minSafeDistance);
                    obj.logWarning(warnings);
                    return;
                end
            end

            % Check velocity bounds
            velocities = state.velocities;
            maxVelocity = obj.config.truck.max_velocity;

            for i = 1:length(velocities)
                if abs(velocities(i)) > maxVelocity
                    warnings.level = 'WARNING';
                    warnings.message = sprintf('Truck %d exceeds velocity limit: %.2f m/s (max: %.2f m/s)', ...
                        i, velocities(i), maxVelocity);
                    obj.logWarning(warnings);
                    return;
                end
            end

            % Check acceleration bounds
            accelerations = state.accelerations;
            maxAccel = obj.config.truck.max_acceleration;
            maxDecel = obj.config.truck.max_deceleration;

            for i = 1:length(accelerations)
                if accelerations(i) > maxAccel
                    warnings.level = 'WARNING';
                    warnings.message = sprintf('Truck %d exceeds acceleration limit: %.2f m/s² (max: %.2f m/s²)', ...
                        i, accelerations(i), maxAccel);
                    obj.logWarning(warnings);
                    return;
                elseif accelerations(i) < maxDecel
                    warnings.level = 'WARNING';
                    warnings.message = sprintf('Truck %d exceeds deceleration limit: %.2f m/s² (min: %.2f m/s²)', ...
                        i, accelerations(i), maxDecel);
                    obj.logWarning(warnings);
                    return;
                end
            end

            % Check emergency deceleration threshold
            emergencyThreshold = obj.config.truck.max_deceleration * 1.5;  % Emergency is 150% of max decel
            if any(accelerations < emergencyThreshold)
                warnings.level = 'EMERGENCY';
                warnings.message = sprintf('Emergency deceleration detected: %.2f m/s² (threshold: %.2f m/s²)', ...
                    min(accelerations), emergencyThreshold);
                obj.logWarning(warnings);
                return;
            end

            % If we get here, everything is safe
            warnings.level = 'INFO';
            warnings.message = 'All safety conditions met';
        end
    end

    methods (Access = private)
        function logWarning(obj, warning)
            % Log warning if enough time has passed since last warning
            currentTime = obj.simulation.getState().time;

            % Check if minimum time between warnings has passed
            if (currentTime - obj.lastWarningTime) >= obj.WARNING_INTERVAL
                switch warning.level
                    case 'ERROR'
                        obj.logger.error(warning.message);
                    case 'WARNING'
                        obj.logger.warning(warning.message);
                    case 'EMERGENCY'
                        obj.logger.error('EMERGENCY: %s', warning.message);
                    otherwise
                        obj.logger.info(warning.message);
                end

                obj.lastWarningTime = currentTime;
            end
        end
    end
end