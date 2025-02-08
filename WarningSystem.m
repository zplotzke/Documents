classdef WarningSystem < handle
    % WARNINGSYSTEM Manages warning generation and frequencies
    %
    % Author: zplotzke
    % Created: 2025-02-08 03:43:20 UTC

    properties (Access = private)
        config              % Configuration parameters
        warningTypes       % Types of warnings that can be generated
        warningFrequencies % How often each warning type should be checked
        lastWarningTimes   % Last time each warning was issued
    end

    methods
        function obj = WarningSystem(config)
            obj.config = config;

            % Define warning types
            obj.warningTypes = {...
                'distance', ...
                'velocity', ...
                'acceleration', ...
                'jerk'};

            % Set default frequencies if not specified in config
            if ~isfield(obj.config.safety, 'warning_frequencies')
                obj.config.safety.warning_frequencies = [0.1, 0.1, 0.1, 0.1];  % 10Hz default
            end

            % Initialize warning frequencies (in seconds)
            obj.warningFrequencies = containers.Map();
            for i = 1:length(obj.warningTypes)
                obj.warningFrequencies(obj.warningTypes{i}) = obj.config.safety.warning_frequencies(i);
            end

            % Initialize last warning times
            obj.lastWarningTimes = containers.Map();
            for i = 1:length(obj.warningTypes)
                obj.lastWarningTimes(obj.warningTypes{i}) = -inf;
            end
        end

        function shouldWarn = checkWarningFrequency(obj, warningType, currentTime)
            % Check if enough time has passed to issue another warning
            if ~obj.lastWarningTimes.isKey(warningType)
                shouldWarn = true;
            else
                timeSinceLastWarning = currentTime - obj.lastWarningTimes(warningType);
                shouldWarn = timeSinceLastWarning >= obj.warningFrequencies(warningType);
            end

            if shouldWarn
                obj.lastWarningTimes(warningType) = currentTime;
            end
        end
    end
end