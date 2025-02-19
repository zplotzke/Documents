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
    % Last Modified: 2025-02-19 15:13:48 UTC
    % Version: 1.1.1

    properties (Access = private)
        config              % Configuration settings
        logger             % Logger instance
        warningTypes       % Map of warning types and their priorities
        lastWarningTimes   % Map of last warning times by type
        warningCounts      % Map of warning counts by type
        activeWarnings     % Currently active warnings
        sonificator        % Sonification system
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
            % Get logger instance first
            obj.logger = utils.Logger.getLogger('WarningSystem');

            % Get configuration directly
            obj.config = config.getConfig();

            % Initialize warning tracking using containers.Map
            obj.initializeWarningTypes();
            obj.resetWarningCounters();

            % Initialize sonification system with proper package reference
            obj.sonificator = utils.Sonificator();

            obj.logger.info('Warning system initialized with sonification');
        end

        function raiseWarning(obj, warningType, message, data)
            % RAISEWARNING Raise a new warning with sonification
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

                % Calculate warning severity (0-1 scale)
                severity = obj.calculateWarningSeverity(warning);

                % Trigger sonification
                obj.sonificator.sonifyWarning(warningType, severity);

                % Handle warning
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

        function enableSonification(obj)
            % ENABLESONIFICATION Enable warning sounds
            obj.sonificator.enable();
        end

        function disableSonification(obj)
            % DISABLESONIFICATION Disable warning sounds
            obj.sonificator.disable();
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

        function severity = calculateWarningSeverity(obj, warning)
            % Calculate warning severity on a 0-1 scale
            severity = 0.5; % Default medium severity

            switch warning.type
                case 'COLLISION'
                    if isfield(warning.data, 'distance')
                        threshold = obj.config.safety.collision_warning_distance;
                        severity = 1 - (warning.data.distance / threshold);
                    else
                        severity = 1.0;
                    end

                case 'EMERGENCY_BRAKE'
                    if isfield(warning.data, 'deceleration')
                        maxDecel = abs(obj.config.truck.max_deceleration);
                        severity = abs(warning.data.deceleration) / maxDecel;
                    end

                case 'DISTANCE'
                    if isfield(warning.data, 'actual_distance') && ...
                            isfield(warning.data, 'required_distance')
                        severity = 1 - (warning.data.actual_distance / ...
                            warning.data.required_distance);
                    end

                case 'SPEED'
                    if isfield(warning.data, 'speed')
                        maxSpeed = obj.config.truck.max_velocity;
                        severity = warning.data.speed / maxSpeed - 1;
                    end
            end

            severity = min(max(severity, 0), 1);
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
        end

        function handleEmergencyBrakeWarning(obj, warning)
            % Handle emergency brake warnings
            obj.logger.warning('EMERGENCY BRAKE: %s', warning.message);
        end

        function handleDistanceWarning(obj, warning)
            % Handle distance violation warnings
            obj.logger.warning('DISTANCE VIOLATION: %s', warning.message);
        end

        function handleSpeedWarning(obj, warning)
            % Handle speed violation warnings
            obj.logger.warning('SPEED VIOLATION: %s', warning.message);
        end
    end
end