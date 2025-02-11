classdef Logger < handle
    % LOGGER Logging utility for truck platoon simulation
    %
    % Provides logging functionality with different severity levels, timestamps,
    % and the ability to log to both console and file.
    %
    % Author: zplotzke
    % Last Modified: 2025-02-11 15:10:11 UTC
    % Version: 1.0.0

    properties (Access = private)
        name            % Logger name
        logLevel        % Current log level
        logFile        % File handle for logging
        config         % Logger configuration
    end

    properties (Constant, Access = private)
        LEVEL_DEBUG = 1
        LEVEL_INFO = 2
        LEVEL_WARNING = 3
        LEVEL_ERROR = 4

        LEVEL_NAMES = containers.Map(...
            {1, 2, 3, 4}, ...
            {'DEBUG', 'INFO', 'WARNING', 'ERROR'})
    end

    methods (Static)
        function logger = getLogger(name)
            % GETLOGGER Get or create a logger instance
            %   logger = Logger.getLogger(name) returns a logger instance with
            %   the specified name. If a logger with that name already exists,
            %   returns the existing instance.

            persistent loggers
            if isempty(loggers)
                loggers = containers.Map();
            end

            if ~loggers.isKey(name)
                loggers(name) = utils.Logger(name);
            end
            logger = loggers(name);
        end
    end

    methods (Access = private)
        function obj = Logger(name)
            % Constructor is private - use getLogger instead
            obj.name = name;
            obj.logLevel = obj.LEVEL_INFO;

            % Get configuration
            obj.config = config.getConfig().logging;

            % Initialize log file if enabled
            if obj.config.file_logging
                logDir = fullfile(pwd, 'logs');
                if ~exist(logDir, 'dir')
                    mkdir(logDir);
                end

                timestamp = datestr(now, 'yyyymmdd_HHMMSS');
                logPath = fullfile(logDir, sprintf('%s_%s.log', name, timestamp));
                obj.logFile = fopen(logPath, 'a');

                if obj.logFile == -1
                    error('Logger:FileError', 'Failed to open log file: %s', logPath);
                end
            end
        end
    end

    methods
        function delete(obj)
            % Destructor - close log file if open
            if ~isempty(obj.logFile) && obj.logFile ~= -1
                fclose(obj.logFile);
            end
        end

        function setLevel(obj, level)
            % SETLEVEL Set the logging level
            if ischar(level)
                switch upper(level)
                    case 'DEBUG'
                        obj.logLevel = obj.LEVEL_DEBUG;
                    case 'INFO'
                        obj.logLevel = obj.LEVEL_INFO;
                    case 'WARNING'
                        obj.logLevel = obj.LEVEL_WARNING;
                    case 'ERROR'
                        obj.logLevel = obj.LEVEL_ERROR;
                    otherwise
                        error('Logger:InvalidLevel', 'Invalid log level: %s', level);
                end
            else
                error('Logger:InvalidLevel', 'Log level must be a string');
            end
        end

        function debug(obj, message, varargin)
            % DEBUG Log debug message
            obj.log(obj.LEVEL_DEBUG, message, varargin{:});
        end

        function info(obj, message, varargin)
            % INFO Log info message
            obj.log(obj.LEVEL_INFO, message, varargin{:});
        end

        function warning(obj, message, varargin)
            % WARNING Log warning message
            obj.log(obj.LEVEL_WARNING, message, varargin{:});
        end

        function error(obj, message, varargin)
            % ERROR Log error message
            obj.log(obj.LEVEL_ERROR, message, varargin{:});
        end
    end

    methods (Access = private)
        function log(obj, level, message, varargin)
            % Internal logging method
            if level >= obj.logLevel
                % Format message
                if ~isempty(varargin)
                    message = sprintf(message, varargin{:});
                end

                % Create log entry
                timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
                logEntry = sprintf('%s [%s] %s: %s\n', ...
                    timestamp, obj.LEVEL_NAMES(level), obj.name, message);

                % Console output if enabled
                if obj.config.console_logging
                    if level >= obj.LEVEL_WARNING
                        fprintf(2, '%s', logEntry);  % stderr for warnings/errors
                    else
                        fprintf(1, '%s', logEntry);  % stdout for info/debug
                    end
                end

                % File output if enabled
                if obj.config.file_logging && obj.logFile ~= -1
                    fprintf(obj.logFile, '%s', logEntry);
                    fflush(obj.logFile);  % Ensure immediate write
                end
            end
        end
    end
end