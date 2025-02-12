classdef Logger < handle
    % LOGGER Logging utility for truck platoon simulation
    %
    % Author: zplotzke
    % Last Modified: 2025-02-11 20:33:20 UTC
    % Version: 1.0.0

    properties (SetAccess = private, GetAccess = public)
        name           % Logger name
        logLevel      % Current log level
    end

    properties (Access = private)
        logFile        % File handle for logging
        config         % Logger configuration
        currentLogPath % Current log file path
        logDir        % Directory for log files
    end

    properties (Constant, GetAccess = public)
        LEVEL_DEBUG = 1
        LEVEL_INFO = 2
        LEVEL_WARNING = 3
        LEVEL_ERROR = 4

        LEVEL_NAMES = containers.Map(...
            {1, 2, 3, 4}, ...
            {'DEBUG', 'INFO', 'WARNING', 'ERROR'})
    end

    methods (Static)
        function logger = getLogger(name, logDir)
            % GETLOGGER Get or create a logger instance
            %   logger = Logger.getLogger(name) returns a logger instance
            %   logger = Logger.getLogger(name, logDir) specifies log directory

            if nargin < 1 || isempty(name)
                name = 'DefaultLogger';
            end
            if nargin < 2
                logDir = fullfile(pwd, 'logs');
            end

            persistent loggers
            if isempty(loggers)
                loggers = containers.Map();
            end

            loggerKey = sprintf('%s_%s', name, logDir);
            if ~loggers.isKey(loggerKey)
                loggers(loggerKey) = utils.Logger(name, logDir);
            end
            logger = loggers(loggerKey);
        end
    end

    methods
        function obj = Logger(name, logDir)
            % Constructor - use getLogger instead for singleton pattern
            if nargin < 1 || isempty(name)
                name = 'DefaultLogger';
            end
            if nargin < 2
                logDir = fullfile(pwd, 'logs');
            end

            if ~(ischar(name) || isstring(name) || isempty(name))
                error('Logger:InvalidName', 'Logger name must be a string or character array');
            end

            obj.name = char(name);
            obj.logLevel = obj.LEVEL_INFO;
            obj.logFile = -1;
            obj.logDir = logDir;
            obj.currentLogPath = '';

            % Initialize default configuration
            obj.config = struct(...
                'file_logging', false, ... % Start with file logging disabled
                'console_logging', true, ...
                'log_format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s');
        end

        function delete(obj)
            % Destructor - close log file if open
            if ~isempty(obj.logFile) && obj.logFile ~= -1
                fclose(obj.logFile);
            end
        end

        function disp(obj)
            % Custom display method for single logger instance
            fprintf('  Logger Instance:\n');
            fprintf('    Name: %s\n', obj.name);
            fprintf('    Log Level: %s\n', obj.LEVEL_NAMES(obj.logLevel));
            [fileLogging, consoleLogging] = obj.getLoggingConfig();
            fprintf('    File Logging: %s\n', mat2str(fileLogging));
            fprintf('    Console Logging: %s\n', mat2str(consoleLogging));
            if fileLogging && ~isempty(obj.currentLogPath)
                fprintf('    Current Log File: %s\n', obj.currentLogPath);
            end
        end

        function display(obj)
            % Custom display method for logger arrays
            fprintf('\n');
            disp(obj);
        end

        function setLevel(obj, level)
            % SETLEVEL Set the logging level
            if ischar(level) || isstring(level)
                switch upper(char(level))
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

        function setFileLogging(obj, enable)
            % SETFILELOGGING Enable or disable file logging
            if ~islogical(enable)
                error('Logger:InvalidConfig', 'File logging value must be logical');
            end

            % Close existing file if disabling
            if ~enable && obj.logFile ~= -1
                fclose(obj.logFile);
                obj.logFile = -1;
                obj.currentLogPath = '';
            end

            % Update configuration
            obj.config.file_logging = enable;

            % Initialize file if enabling
            if enable
                obj.initializeLogFile();
            end
        end

        function setConsoleLogging(obj, enable)
            % SETCONSOLELOGGING Enable or disable console logging
            if ~islogical(enable)
                error('Logger:InvalidConfig', 'Console logging value must be logical');
            end
            obj.config.console_logging = enable;
        end

        function [fileLogging, consoleLogging] = getLoggingConfig(obj)
            % GETLOGGINGCONFIG Get current logging configuration
            fileLogging = obj.config.file_logging;
            consoleLogging = obj.config.console_logging;
        end
    end

    methods (Access = private)
        function initializeLogFile(obj)
            % Initialize log file with timestamp in filename
            if ~obj.config.file_logging
                return;  % Don't create file if file logging is disabled
            end

            % Ensure directory exists
            if ~exist(obj.logDir, 'dir')
                [success, msg] = mkdir(obj.logDir);
                if ~success
                    warning('Logger:DirError', 'Failed to create log directory: %s', msg);
                    return;
                end
            end

            % Close existing file if open
            if obj.logFile ~= -1
                fclose(obj.logFile);
                obj.logFile = -1;
            end

            % Create new file
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            obj.currentLogPath = fullfile(obj.logDir, sprintf('%s_%s.log', obj.name, timestamp));

            [obj.logFile, errmsg] = fopen(obj.currentLogPath, 'a');
            if obj.logFile == -1
                warning('Logger:FileError', 'Failed to open log file: %s', errmsg);
                obj.currentLogPath = '';
            end
        end

        function log(obj, level, message, varargin)
            % Internal logging method
            if level >= obj.logLevel
                % Format message with variable arguments if provided
                if ~isempty(varargin)
                    try
                        message = sprintf(message, varargin{:});
                    catch
                        message = 'Error formatting message';
                    end
                end

                % Create log entry with timestamp
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

                % File output if enabled and file is open
                if obj.config.file_logging
                    if obj.logFile == -1
                        obj.initializeLogFile();
                    end
                    if obj.logFile ~= -1
                        fprintf(obj.logFile, '%s', logEntry);
                        if level >= obj.LEVEL_WARNING
                            fclose(obj.logFile);
                            obj.logFile = fopen(obj.currentLogPath, 'a');
                        end
                    end
                end
            end
        end
    end
end