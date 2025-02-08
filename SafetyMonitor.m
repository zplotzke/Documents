classdef SafetyMonitor < handle
    % SAFETYMONITOR Monitors truck platoon safety conditions
    %
    % Author: zplotzke
    % Created: 2025-02-08 03:43:20 UTC

    properties (Access = private)
        config          % Configuration parameters
        logger          % Logger instance
        warningSystem   % Warning system instance
    end

    methods
        function obj = SafetyMonitor(config, logger)
            obj.config = config;
            obj.logger = logger;
            obj.warningSystem = WarningSystem(config);
        end

        function [is_safe, violations] = checkSafetyConditions(obj, pos, vel, acc, jerk)
            is_safe = true;
            violations = struct('type', {}, 'message', {}, 'value', {});
            currentTime = pos(1);  % Use lead truck position as time proxy

            % Check relative distances
            for i = 2:length(pos)
                distance = abs(pos(i) - pos(i-1));
                if distance < obj.config.safety.min_safe_distance && ...
                        obj.warningSystem.checkWarningFrequency('distance', currentTime)
                    is_safe = false;
                    violations(end+1).type = 'distance';
                    violations(end).message = sprintf('Unsafe distance %.2f m between trucks %d and %d', ...
                        distance, i-1, i);
                    violations(end).value = distance;
                end
            end

            % Check relative velocities
            for i = 2:length(vel)
                rel_vel = vel(i) - vel(i-1);
                if abs(rel_vel) > obj.config.safety.max_relative_velocity && ...
                        obj.warningSystem.checkWarningFrequency('velocity', currentTime)
                    is_safe = false;
                    violations(end+1).type = 'velocity';
                    violations(end).message = sprintf('Excessive relative velocity %.2f m/s between trucks %d and %d', ...
                        rel_vel, i-1, i);
                    violations(end).value = rel_vel;
                end
            end

            % Check accelerations
            for i = 1:length(acc)
                if abs(acc(i)) > obj.config.safety.max_acceleration && ...
                        obj.warningSystem.checkWarningFrequency('acceleration', currentTime)
                    is_safe = false;
                    violations(end+1).type = 'acceleration';
                    violations(end).message = sprintf('Excessive acceleration %.2f m/s^2 for truck %d', ...
                        acc(i), i);
                    violations(end).value = acc(i);
                end
            end

            % Check jerks
            for i = 1:length(jerk)
                if abs(jerk(i)) > obj.config.safety.max_jerk && ...
                        obj.warningSystem.checkWarningFrequency('jerk', currentTime)
                    is_safe = false;
                    violations(end+1).type = 'jerk';
                    violations(end).message = sprintf('Excessive jerk %.2f m/s^3 for truck %d', ...
                        jerk(i), i);
                    violations(end).value = jerk(i);
                end
            end
        end

        function logViolations(obj, violations, time)
            for i = 1:length(violations)
                obj.logger.warning('Time %.2f: %s', time, violations(i).message);
            end
        end
    end
end