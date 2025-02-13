classdef WarningSystem < handle
    % WARNINGSYSTEM Warning management system for truck platoon
    %
    % Manages and tracks different types of warnings including:
    % - Collision warnings
    % - Speed violations
    % - Distance violations
    % - Emergency brake warnings
    %
    % Author: zplotzke
    % Last Modified: 2025-02-13 02:07:26 UTC
    % Version: 1.0.5

    properties (Access = private)
        config              % Configuration settings
        logger             % Logger instance
        warningTypes       % Map of warning types and their priorities
        lastWarningTimes   % Map of last warning times by type
        warningCounts      % Map of warning counts by type
        activeWarnings     % Currently active warnings
    end

    properties (Constant)
        WARNING_TYPES = containers.Map(...
            {'COLLISION', 'SPEED', 'DISTANCE', 'EMERGENCY_BRAKE'}, ...
            {1, 2, 3, 4})

        WARNING_PRIORITIES = containers.Map(...
            {'HIGH', 'MEDIUM', 'LOW'}, ...
            {1, 2, 3})
    end

    methods
        function obj = WarningSystem()
            % Constructor
            % Get logger instance first
            obj.logger = utils.Logger.getLogger('WarningSystem');

            % Get configuration directly
            obj.config = config.getConfig();

            % Initialize warning tracking using containers.Map
            obj.initializeWarningTypes();
            obj.resetWarningCounters();

            obj.logger.info('Warning system initialized');
        end

        function raiseWarning(obj, warningType, message, data)
            % RAISEWARNING Raise a new warning
            if ~obj.WARNING_TYPES.isKey(warningType)
                obj.logger.error('Invalid warning type: %s', warningType);
                return;
            end

            currentTime = now;
            warningTypeId = obj.WARNING_TYPES(warningType);

            % Check warning timeout
            if obj.checkWarningTimeout(warningType, currentTime)
                % Update warning counts and timestamps
                obj.warningCounts(warningType) = obj.warningCounts(warningType) + 1;
                obj.lastWarningTimes(warningType) = currentTime;

                % Log warning
                obj.logger.warning('[%s] %s', warningType, message);

                % Add to active warnings
                warning = struct(...
                    'type', warningType, ...
                    'message', message, ...
                    'timestamp', currentTime, ...
                    'data', data ...
                    );
                obj.activeWarnings{end+1} = warning;

                % Trigger appropriate response based on warning type
                obj.handleWarning(warning);
            end
        end

        function warnings = getActiveWarnings(obj)
            % GETACTIVEWARNINGS Get list of currently active warnings
            warnings = obj.activeWarnings;
        end

        function stats = getWarningStats(obj)
            % GETWARNINGSTATS Get warning statistics
            stats = struct(...
                'counts', containers.Map(obj.warningCounts.keys, obj.warningCounts.values), ...
                'lastWarnings', containers.Map(obj.lastWarningTimes.keys, obj.lastWarningTimes.values) ...
                );
        end

        function clearWarnings(obj)
            % CLEARWARNINGS Clear all active warnings
            obj.activeWarnings = {};
            obj.resetWarningCounters();
            obj.logger.info('All warnings cleared');
        end
    end

    methods (Access = private)
        function initializeWarningTypes(obj)
            % Initialize warning type configurations
            obj.warningTypes = containers.Map();

            % Collision warnings (highest priority)
            obj.warningTypes('COLLISION') = struct(...
                'priority', obj.WARNING_PRIORITIES('HIGH'), ...
                'timeout', obj.config.safety.warning_timeout, ...
                'threshold', obj.config.safety.collision_warning_distance ...
                );

            % Emergency brake warnings
            obj.warningTypes('EMERGENCY_BRAKE') = struct(...
                'priority', obj.WARNING_PRIORITIES('HIGH'), ...
                'timeout', obj.config.safety.warning_timeout, ...
                'threshold', obj.config.safety.emergency_decel_threshold ...
                );

            % Distance violations
            obj.warningTypes('DISTANCE') = struct(...
                'priority', obj.WARNING_PRIORITIES('MEDIUM'), ...
                'timeout', obj.config.safety.warning_timeout * 2, ...
                'threshold', obj.config.safety.min_following_time ...
                );

            % Speed violations
            obj.warningTypes('SPEED') = struct(...
                'priority', obj.WARNING_PRIORITIES('LOW'), ...
                'timeout', obj.config.safety.warning_timeout * 3, ...
                'threshold', obj.config.truck.max_velocity ...
                );
        end

        function resetWarningCounters(obj)
            % Reset warning counters and timestamps
            warningTypes = obj.WARNING_TYPES.keys;

            % Initialize counters map
            obj.warningCounts = containers.Map();
            obj.lastWarningTimes = containers.Map();

            for i = 1:length(warningTypes)
                warningType = warningTypes{i};
                obj.warningCounts(warningType) = 0;
                obj.lastWarningTimes(warningType) = 0;
            end

            obj.activeWarnings = {};
        end

        function timeout = checkWarningTimeout(obj, warningType, currentTime)
            % Check if enough time has passed since last warning
            lastWarning = obj.lastWarningTimes(warningType);
            minTimeout = obj.warningTypes(warningType).timeout;
            timeout = (currentTime - lastWarning) * 86400 >= minTimeout;
        end

        function handleWarning(obj, warning)
            % Handle specific warning types
            switch warning.type
                case 'COLLISION'
                    obj.handleCollisionWarning(warning);
                case 'EMERGENCY_BRAKE'
                    obj.handleEmergencyBrakeWarning(warning);
                case 'DISTANCE'
                    obj.handleDistanceWarning(warning);
                case 'SPEED'
                    obj.handleSpeedWarning(warning);
            end
        end

        function handleCollisionWarning(obj, warning)
            % Handle collision warnings (highest priority)
            obj.logger.error('COLLISION WARNING: %s', warning.message);
            % Additional collision-specific handling could be added here
        end

        function handleEmergencyBrakeWarning(obj, warning)
            % Handle emergency brake warnings
            obj.logger.warning('EMERGENCY BRAKE: %s', warning.message);
            % Additional emergency brake-specific handling could be added here
        end

        function handleDistanceWarning(obj, warning)
            % Handle distance violation warnings
            obj.logger.warning('DISTANCE VIOLATION: %s', warning.message);
            % Additional distance-specific handling could be added here
        end

        function handleSpeedWarning(obj, warning)
            % Handle speed violation warnings
            obj.logger.warning('SPEED VIOLATION: %s', warning.message);
            % Additional speed-specific handling could be added here
        end
    end
end