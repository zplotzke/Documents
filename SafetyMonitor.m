classdef SafetyMonitor < handle
    % SAFETYMONITOR Monitors safety conditions for truck platoon
    %
    % Monitors and enforces safety conditions including:
    % - Inter-vehicle distances
    % - Speed limits
    % - Acceleration bounds
    % - Emergency situations
    %
    % Author: zplotzke
    % Last Modified: 2025-02-11 16:43:36 UTC
    % Version: 1.0.6

    properties (SetAccess = private, GetAccess = public)
        config      % Configuration parameters
        warnings    % Warning system instance
    end

    properties (Access = private)
        logger      % Logger instance
    end

    methods
        function obj = SafetyMonitor(varargin)
            % Constructor
            % Usage: obj = SafetyMonitor() or obj = SafetyMonitor(config)

            % Get logger instance
            obj.logger = utils.Logger.getLogger('SafetyMonitor');

            % Handle optional config parameter
            if nargin < 1 || isempty(varargin{1})
                obj.logger.info('No config provided, using default configuration');
                obj.config = config.getConfig();
            else
                obj.config = varargin{1};
            end

            % Initialize warning system
            obj.warnings = utils.WarningSystem(obj.config);
            obj.logger.info('Safety monitor initialized');
        end

        function [is_safe, violations] = checkSafetyConditions(obj, positions, velocities, accelerations, jerks)
            % Check all safety conditions and return violations
            is_safe = true;
            violations = {};

            % Check inter-vehicle distances
            [dist_safe, dist_violations] = obj.checkDistances(positions, velocities);
            if ~dist_safe
                is_safe = false;
                violations = [violations, dist_violations];
            end

            % Check speed limits
            [speed_safe, speed_violations] = obj.checkSpeeds(velocities);
            if ~speed_safe
                is_safe = false;
                violations = [violations, speed_violations];
            end

            % Check acceleration bounds
            [accel_safe, accel_violations] = obj.checkAccelerations(accelerations);
            if ~accel_safe
                is_safe = false;
                violations = [violations, accel_violations];
            end

            % Check for emergency conditions
            [emergency_safe, emergency_violations] = obj.checkEmergencyConditions(positions, velocities, accelerations, jerks);
            if ~emergency_safe
                is_safe = false;
                violations = [violations, emergency_violations];
            end

            % Log violations
            if ~is_safe
                obj.logViolations(violations);
            end
        end
    end

    methods (Access = private)
        function [is_safe, violations] = checkDistances(obj, positions, velocities)
            % Check minimum safe following distances
            is_safe = true;
            violations = {};

            for i = 2:length(positions)
                dist = positions(i-1) - positions(i);
                current_velocity = velocities(i);

                % Calculate both minimum distance criteria
                time_based_dist = obj.config.safety.min_following_time * current_velocity;
                abs_min_dist = obj.config.truck.min_safe_distance;

                % Only violate if we're below both thresholds
                if dist < abs_min_dist && dist < time_based_dist
                    is_safe = false;
                    min_dist = max(abs_min_dist, time_based_dist);
                    violation = struct(...
                        'type', 'DISTANCE', ...
                        'message', sprintf('Distance violation between trucks %d and %d: %.2fm', i-1, i, dist), ...
                        'data', struct(...
                        'trucks', [i-1, i], ...
                        'distance', dist, ...
                        'min_required', min_dist, ...
                        'min_absolute', abs_min_dist, ...
                        'min_time_based', time_based_dist) ...
                        );
                    violations{end+1} = violation;
                    obj.warnings.raiseWarning('DISTANCE', violation.message, violation.data);
                end
            end
        end

        function [is_safe, violations] = checkSpeeds(obj, velocities)
            % Check velocity bounds
            is_safe = true;
            violations = {};

            max_vel = obj.config.truck.max_velocity;
            min_vel = 0;  % Minimum velocity is always 0

            for i = 1:length(velocities)
                if velocities(i) > max_vel || velocities(i) < min_vel
                    is_safe = false;
                    violation = struct(...
                        'type', 'SPEED', ...
                        'message', sprintf('Speed violation for truck %d: %.2f m/s', i, velocities(i)), ...
                        'data', struct('truck', i, 'speed', velocities(i), 'bounds', [min_vel, max_vel]) ...
                        );
                    violations{end+1} = violation;
                    obj.warnings.raiseWarning('SPEED', violation.message, violation.data);
                end
            end
        end

        function [is_safe, violations] = checkAccelerations(obj, accelerations)
            % Check acceleration bounds
            is_safe = true;
            violations = {};

            max_accel = obj.config.truck.max_acceleration;
            min_accel = obj.config.truck.max_deceleration;  % Using max_deceleration from config

            for i = 1:length(accelerations)
                if accelerations(i) > max_accel || accelerations(i) < min_accel
                    is_safe = false;
                    violation = struct(...
                        'type', 'ACCELERATION', ...
                        'message', sprintf('Acceleration violation for truck %d: %.2f m/s²', i, accelerations(i)), ...
                        'data', struct('truck', i, 'acceleration', accelerations(i), 'bounds', [min_accel, max_accel]) ...
                        );
                    violations{end+1} = violation;
                    obj.warnings.raiseWarning('ACCELERATION', violation.message, violation.data);
                end
            end
        end

        function [is_safe, violations] = checkEmergencyConditions(obj, positions, velocities, accelerations, ~)
            % Check for emergency conditions
            is_safe = true;
            violations = {};

            % Check for imminent collisions
            collision_warning_dist = obj.config.safety.collision_warning_distance;
            for i = 2:length(positions)
                dist = positions(i-1) - positions(i);
                rel_velocity = velocities(i) - velocities(i-1);

                % If trucks are getting closer and distance is small
                if dist < collision_warning_dist && rel_velocity > 0
                    is_safe = false;
                    violation = struct(...
                        'type', 'COLLISION', ...
                        'message', sprintf('Imminent collision warning between trucks %d and %d!', i-1, i), ...
                        'data', struct(...
                        'trucks', [i-1, i], ...
                        'distance', dist, ...
                        'relative_velocity', rel_velocity ...
                        ) ...
                        );
                    violations{end+1} = violation;
                    obj.warnings.raiseWarning('COLLISION', violation.message, violation.data);
                end
            end

            % Check for emergency braking
            emergency_decel = obj.config.safety.emergency_decel_threshold;
            for i = 1:length(accelerations)
                if accelerations(i) < emergency_decel
                    is_safe = false;
                    violation = struct(...
                        'type', 'EMERGENCY_BRAKE', ...
                        'message', sprintf('Emergency braking detected for truck %d!', i), ...
                        'data', struct(...
                        'truck', i, ...
                        'deceleration', accelerations(i), ...
                        'threshold', emergency_decel ...
                        ) ...
                        );
                    violations{end+1} = violation;
                    obj.warnings.raiseWarning('EMERGENCY_BRAKE', violation.message, violation.data);
                end
            end
        end

        function logViolations(obj, violations)
            % Log all violations
            for i = 1:length(violations)
                violation = violations{i};
                obj.logger.warning('Safety violation: [%s] %s', ...
                    violation.type, violation.message);
            end
        end
    end
end