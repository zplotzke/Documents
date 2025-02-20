classdef SafetyMonitor < handle
    % SAFETYMONITOR Safety monitoring system for truck platoon
    %
    % This class monitors safety conditions for the truck platoon including:
    % - Following distances
    % - Speed limits
    % - Acceleration limits
    % - Jerk limits
    %
    % Author: zplotzke
    % Last Modified: 2025-02-19 20:05:04 UTC
    % Version: 1.1.3

    properties (Access = private)
        config          % Configuration settings
        logger          % Logger instance
        simulation      % Reference to simulation
        lastCheckTime   % Time of last safety check
        warningSystem   % Reference to warning system
    end

    methods
        function obj = SafetyMonitor()
            obj.config = config.getConfig();
            obj.logger = utils.Logger.getLogger('SafetyMonitor');
            obj.lastCheckTime = 0;
            obj.warningSystem = utils.WarningSystem();
            obj.logger.info('Safety monitor initialized');
        end

        function setSimulation(obj, sim)
            obj.simulation = sim;
        end

        function setWarningSystem(obj, warningSystem)
            obj.warningSystem = warningSystem;
        end

        function [is_safe, violations] = checkSafetyConditions(obj, positions, velocities, accelerations, jerks)
            % CHECKSAFETYCONDITIONS Check all safety conditions for the platoon
            %
            % Parameters:
            %   positions - Array of truck positions (meters)
            %   velocities - Array of truck velocities (m/s)
            %   accelerations - Array of truck accelerations (m/s^2)
            %   jerks - Array of truck jerks (m/s^3)
            %
            % Returns:
            %   is_safe - Boolean indicating if all safety conditions are met
            %   violations - Structure containing details of any violations

            violations = struct();
            is_safe = true;

            % Check minimum following distance
            min_distance = obj.checkFollowingDistance(positions);
            if ~min_distance.safe
                is_safe = false;
                violations.distance = min_distance;
                obj.warningSystem.raiseWarning('DISTANCE', min_distance.message, ...
                    struct('actual_distance', min_distance.distance, ...
                    'required_distance', min_distance.required));
            end

            % Check speed limits
            speed_check = obj.checkSpeedLimits(velocities);
            if ~speed_check.safe
                is_safe = false;
                violations.speed = speed_check;
                obj.warningSystem.raiseWarning('SPEED', speed_check.message, ...
                    struct('speed', speed_check.speed, ...
                    'max_speed', speed_check.limit));
            end

            % Check acceleration limits
            accel_check = obj.checkAccelerationLimits(accelerations);
            if ~accel_check.safe
                is_safe = false;
                violations.acceleration = accel_check;
                obj.warningSystem.raiseWarning('EMERGENCY_BRAKE', accel_check.message, ...
                    struct('acceleration', accel_check.acceleration, ...
                    'limit', accel_check.limit));
            end

            % Check jerk limits
            jerk_check = obj.checkJerkLimits(jerks);
            if ~jerk_check.safe
                is_safe = false;
                violations.jerk = jerk_check;
                obj.warningSystem.raiseWarning('COLLISION', jerk_check.message, ...
                    struct('jerk', jerk_check.jerk, ...
                    'limit', jerk_check.limit));
            end

            % Log violations if any
            if ~is_safe
                obj.logViolations(violations);
            end
        end

        function logViolations(obj, violations, time)
            % LOGVIOLATIONS Log safety violations with timestamps
            %
            % Parameters:
            %   violations - Structure containing violation details
            %   time - Current simulation time (optional)

            fields = fieldnames(violations);
            for i = 1:length(fields)
                field = fields{i};
                violation = violations.(field);
                if nargin > 2
                    obj.logger.warning('Safety violation at t=%.2fs: %s', time, violation.message);
                else
                    obj.logger.warning('Safety violation: %s', violation.message);
                end
            end
        end
    end

    methods (Access = private)
        function result = checkFollowingDistance(obj, positions)
            result = struct('safe', true, ...
                'message', '', ...
                'distance', 0, ...
                'required', 0);

            min_safe_distance = obj.config.safety.collision_warning_distance;

            for i = 2:length(positions)
                distance = positions(i) - positions(i-1);  % Fixed calculation order
                if distance < min_safe_distance
                    result.safe = false;
                    result.distance = distance;
                    result.required = min_safe_distance;
                    result.message = sprintf('Following distance violation: %.2f m (min: %.2f m)', ...
                        distance, min_safe_distance);
                    return;
                end
            end
        end

        function result = checkSpeedLimits(obj, velocities)
            result = struct('safe', true, ...
                'message', '', ...
                'speed', 0, ...
                'limit', obj.config.truck.max_velocity);

            for i = 1:length(velocities)
                if abs(velocities(i)) > obj.config.truck.max_velocity
                    result.safe = false;
                    result.speed = abs(velocities(i));
                    result.message = sprintf('Speed limit violation: %.2f m/s (max: %.2f m/s)', ...
                        abs(velocities(i)), obj.config.truck.max_velocity);
                    return;
                end
            end
        end

        function result = checkAccelerationLimits(obj, accelerations)
            result = struct('safe', true, ...
                'message', '', ...
                'acceleration', 0, ...
                'limit', struct('max', obj.config.truck.max_acceleration, ...
                'min', obj.config.truck.max_deceleration));

            for i = 1:length(accelerations)
                if accelerations(i) > obj.config.truck.max_acceleration || ...
                        accelerations(i) < obj.config.truck.max_deceleration
                    result.safe = false;
                    result.acceleration = accelerations(i);
                    result.message = sprintf('Acceleration limit violation: %.2f m/s² (limits: %.2f to %.2f)', ...
                        accelerations(i), obj.config.truck.max_deceleration, ...
                        obj.config.truck.max_acceleration);
                    return;
                end
            end
        end

        function result = checkJerkLimits(obj, jerks)
            result = struct('safe', true, ...
                'message', '', ...
                'jerk', 0, ...
                'limit', obj.config.truck.max_jerk);

            for i = 1:length(jerks)
                if abs(jerks(i)) > obj.config.truck.max_jerk
                    result.safe = false;
                    result.jerk = abs(jerks(i));
                    result.message = sprintf('Jerk limit violation: %.2f m/s³ (max: %.2f)', ...
                        abs(jerks(i)), obj.config.truck.max_jerk);
                    return;
                end
            end
        end
    end
end