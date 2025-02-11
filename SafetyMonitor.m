classdef SafetyMonitor < handle
    % SAFETYMONITOR Safety monitoring system for truck platoon
    %
    % Monitors and enforces safety constraints for the truck platoon:
    % - Following distances
    % - Speed limits
    % - Acceleration/deceleration limits
    % - Jerk limits
    % - Emergency situations
    %
    % Author: zplotzke
    % Last Modified: 2025-02-11 15:16:15 UTC
    % Version: 1.0.0

    properties (Access = private)
        config          % Configuration settings
        logger          % Logger instance
        warningSystem   % Warning system instance
        violations      % Current safety violations
        safetyMetrics   % Historical safety metrics
    end

    methods
        function obj = SafetyMonitor(config)
            % Constructor
            obj.config = config;
            obj.logger = utils.Logger.getLogger('SafetyMonitor');
            obj.warningSystem = utils.WarningSystem(config);
            obj.violations = struct('count', 0, 'active', []);
            obj.initializeSafetyMetrics();

            obj.logger.info('Safety monitor initialized');
        end

        function [is_safe, violations] = checkSafetyConditions(obj, positions, velocities, accelerations, jerks)
            % CHECKSAFETYCONDITIONS Check all safety conditions for current state
            %   [is_safe, violations] = checkSafetyConditions(obj, positions,
            %   velocities, accelerations, jerks) returns safety status and
            %   any violations

            obj.violations.active = [];
            is_safe = true;

            % Check following distances
            if ~obj.checkFollowingDistances(positions, velocities)
                is_safe = false;
            end

            % Check speed limits
            if ~obj.checkSpeedLimits(velocities)
                is_safe = false;
            end

            % Check acceleration limits
            if ~obj.checkAccelerationLimits(accelerations)
                is_safe = false;
            end

            % Check jerk limits
            if ~obj.checkJerkLimits(jerks)
                is_safe = false;
            end

            % Check emergency conditions
            if obj.checkEmergencyConditions(positions, velocities, accelerations)
                is_safe = false;
            end

            violations = obj.violations.active;

            % Update metrics
            obj.updateSafetyMetrics(is_safe);
        end

        function logViolations(obj, violations, currentTime)
            % LOGVIOLATIONS Log safety violations
            for i = 1:length(violations)
                violation = violations(i);
                obj.logger.warning('Safety violation at time %.2f: %s', ...
                    currentTime, violation.message);

                % Raise appropriate warning
                obj.warningSystem.raiseWarning(violation.type, ...
                    violation.message, violation.data);
            end
        end

        function metrics = getSafetyMetrics(obj)
            % GETSAFETYMETRICS Get current safety metrics
            metrics = obj.safetyMetrics;
        end
    end

    methods (Access = private)
        function initializeSafetyMetrics(obj)
            % Initialize safety metrics structure
            obj.safetyMetrics = struct(...
                'violationCount', 0, ...
                'safetyScore', 100, ...
                'minFollowingDistance', inf, ...
                'maxSpeed', 0, ...
                'maxDeceleration', 0, ...
                'emergencyEvents', 0 ...
                );
        end

        function updateSafetyMetrics(obj, is_safe)
            % Update safety metrics based on current state
            if ~is_safe
                obj.safetyMetrics.violationCount = obj.safetyMetrics.violationCount + 1;
                obj.safetyMetrics.safetyScore = max(0, ...
                    obj.safetyMetrics.safetyScore - length(obj.violations.active));
            end
        end

        function safe = checkFollowingDistances(obj, positions, velocities)
            % Check minimum following distances between trucks
            safe = true;
            for i = 1:length(positions)-1
                % Calculate time gap and distance to leading vehicle
                distance = positions(i) - positions(i+1);
                timeGap = distance / max(velocities(i+1), 0.1);

                if timeGap < obj.config.safety.min_following_time
                    safe = false;
                    violation = struct(...
                        'type', 'DISTANCE', ...
                        'message', sprintf('Insufficient following distance for truck %d', i+1), ...
                        'data', struct('distance', distance, 'timeGap', timeGap) ...
                        );
                    obj.violations.active = [obj.violations.active, violation];

                    % Update metrics
                    obj.safetyMetrics.minFollowingDistance = ...
                        min(obj.safetyMetrics.minFollowingDistance, distance);
                end
            end
        end

        function safe = checkSpeedLimits(obj, velocities)
            % Check speed limits for all trucks
            safe = true;
            for i = 1:length(velocities)
                if velocities(i) > obj.config.truck.max_velocity
                    safe = false;
                    violation = struct(...
                        'type', 'SPEED', ...
                        'message', sprintf('Speed limit exceeded by truck %d', i), ...
                        'data', struct('speed', velocities(i)) ...
                        );
                    obj.violations.active = [obj.violations.active, violation];

                    % Update metrics
                    obj.safetyMetrics.maxSpeed = ...
                        max(obj.safetyMetrics.maxSpeed, velocities(i));
                end
            end
        end

        function safe = checkAccelerationLimits(obj, accelerations)
            % Check acceleration/deceleration limits
            safe = true;
            for i = 1:length(accelerations)
                if accelerations(i) < obj.config.truck.max_deceleration || ...
                        accelerations(i) > obj.config.truck.max_acceleration
                    safe = false;
                    violation = struct(...
                        'type', 'EMERGENCY_BRAKE', ...
                        'message', sprintf('Acceleration limits exceeded by truck %d', i), ...
                        'data', struct('acceleration', accelerations(i)) ...
                        );
                    obj.violations.active = [obj.violations.active, violation];

                    % Update metrics
                    obj.safetyMetrics.maxDeceleration = ...
                        min(obj.safetyMetrics.maxDeceleration, accelerations(i));
                end
            end
        end

        function safe = checkJerkLimits(obj, jerks)
            % Check jerk limits
            safe = true;
            for i = 1:length(jerks)
                if abs(jerks(i)) > obj.config.truck.max_jerk
                    safe = false;
                    violation = struct(...
                        'type', 'EMERGENCY_BRAKE', ...
                        'message', sprintf('Jerk limits exceeded by truck %d', i), ...
                        'data', struct('jerk', jerks(i)) ...
                        );
                    obj.violations.active = [obj.violations.active, violation];
                end
            end
        end

        function emergency = checkEmergencyConditions(obj, positions, velocities, ~)
            % Check for emergency conditions
            emergency = false;

            % Check for imminent collisions
            for i = 1:length(positions)-1
                distance = positions(i) - positions(i+1);
                relativeVelocity = velocities(i+1) - velocities(i);

                % Time to collision calculation
                if relativeVelocity > 0
                    timeToCollision = distance / relativeVelocity;

                    if timeToCollision < obj.config.safety.min_following_time
                        emergency = true;
                        violation = struct(...
                            'type', 'COLLISION', ...
                            'message', sprintf('Imminent collision detected for truck %d', i+1), ...
                            'data', struct('ttc', timeToCollision) ...
                            );
                        obj.violations.active = [obj.violations.active, violation];

                        % Update metrics
                        obj.safetyMetrics.emergencyEvents = ...
                            obj.safetyMetrics.emergencyEvents + 1;
                    end
                end
            end
        end
    end
end