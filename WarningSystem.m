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
    % Last Modified: 2025-02-11 15:12:22 UTC
    % Version: 1.0.0

    properties (Access = private)
        config              % Configuration settings
        logger             % Logger instance
        warningTypes       % Map of warning types and their priorities
        lastWarningTimes   % Timestamps of last warnings by type
        warningCounts      % Count of warnings by type
        activeWarnings     % Currently active warnings
    end

    properties (Constant, Access = private)
        WARNING_TYPES = struct(...
            'COLLISION', 1, ...
            'SPEED', 2, ...
            'DISTANCE', 3, ...
            'EMERGENCY_BRAKE', 4 ...
            )

        WARNING_PRIORITIES = struct(...
            'HIGH', 1, ...
            'MEDIUM', 2, ...
            'LOW', 3 ...
            )
    end

    methods
        function obj = WarningSystem(config)
            % Constructor
            obj.config = config;
            obj.logger = utils.Logger.getLogger('WarningSystem');

            % Initialize warning tracking
            obj.initializeWarningTypes();
            obj.resetWarningCounters();
        end

        function raiseWarning(obj, warningType, message, data)
            % RAISEWARNING Raise a new warning
            %   raiseWarning(obj, warningType, message, data) raises a warning
            %   of the specified type with the given message and data

            if ~isfield(obj.WARNING_TYPES, warningType)
                obj.logger.error('Invalid warning type: %s', warningType);
                return;
            end

            currentTime = now;
            warningTypeId = obj.WARNING_TYPES.(warningType);

            % Check warning timeout
            if obj.checkWarningTimeout(warningTypeId, currentTime)
                % Update warning counts and timestamps
                obj.warningCounts(warningTypeId) = obj.warningCounts(warningTypeId) + 1;
                obj.lastWarningTimes(warningTypeId) = currentTime;

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
                'counts', obj.warningCounts, ...
                'lastWarnings', obj.lastWarningTimes ...
                );
        end

        function clearWarnings(obj)
            % CLEARWARNINGS Clear all active warnings
            obj.activeWarnings = {};
            obj.logger.info('All warnings cleared');
        end
    end

    methods (Access = private)
        function initializeWarningTypes(obj)
            % Initialize warning type configurations
            obj.warningTypes = containers.Map();

            % Collision warnings (highest priority)
            obj.warningTypes('COLLISION') = struct(...
                'priority', obj.WARNING_PRIORITIES.HIGH, ...
                'timeout', obj.config.safety.warning_timeout, ...
                'threshold', obj.config.safety.collision_warning_distance ...
                );

            % Emergency brake warnings
            obj.warningTypes('EMERGENCY_BRAKE') = struct(...
                'priority', obj.WARNING_PRIORITIES.HIGH, ...
                'timeout', obj.config.safety.warning_timeout, ...
                'threshold', obj.config.safety.emergency_decel_threshold ...
                );

            % Distance violations
            obj.warningTypes('DISTANCE') = struct(...
                'priority', obj.WARNING_PRIORITIES.MEDIUM, ...
                'timeout', obj.config.safety.warning_timeout * 2, ...
                'threshold', obj.config.safety.min_following_time ...
                );

            % Speed violations
            obj.warningTypes('SPEED') = struct(...
                'priority', obj.WARNING_PRIORITIES.LOW, ...
                'timeout', obj.config.safety.warning_timeout * 3, ...
                'threshold', obj.config.truck.max_velocity ...
                );
        end

        function resetWarningCounters(obj)
            % Reset warning counters and timestamps
            warningTypeIds = cell2mat(values(obj.WARNING_TYPES));
            obj.warningCounts = zeros(1, length(warningTypeIds));
            obj.lastWarningTimes = zeros(1, length(warningTypeIds));
            obj.activeWarnings = {};
        end

        function timeout = checkWarningTimeout(obj, warningTypeId, currentTime)
            % Check if enough time has passed since last warning
            lastWarning = obj.lastWarningTimes(warningTypeId);
            warningType = char(obj.WARNING_TYPES(warningTypeId));
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

        % Warning type specific handlers
        function handleCollisionWarning(obj, warning)
            obj.logger.error('COLLISION WARNING: %s', warning.message);
            % Additional collision-specific handling could be added here
        end

        function handleEmergencyBrakeWarning(obj, warning)
            obj.logger.warning('EMERGENCY BRAKE: %s', warning.message);
            % Additional emergency brake-specific handling could be added here
        end

        function handleDistanceWarning(obj, warning)
            obj.logger.warning('DISTANCE VIOLATION: %s', warning.message);
            % Additional distance-specific handling could be added here
        end

        function handleSpeedWarning(obj, warning)
            obj.logger.warning('SPEED VIOLATION: %s', warning.message);
            % Additional speed-specific handling could be added here
        end
    end
end