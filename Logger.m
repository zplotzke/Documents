classdef Logger < handle
    % LOGGER Logging utility for truck platoon simulation
    %
    % Usage:
    %   logger = utils.Logger.getLogger('ComponentName');
    %   logger = utils.Logger('ComponentName');    % Direct initialization
    %   logger = utils.Logger();                   % Default initialization
    %
    % Author: zplotzke
    % Last Modified: 2025-02-11 15:58:01 UTC
    % Version: 1.0.7

    properties (Access = private)
        name           % Logger name
        logLevel       % Current log level
        logFile        % File handle for logging
        config         % Logger configuration
        lastLogTime    % Time of last log message (for rate limiting)
        lastMessages   % Map to store last message for each severity level
        utcOffset      % Offset from local time to UTC in hours
    end

    properties (Constant, Access = private)
        LEVEL_DEBUG = 1
        LEVEL_INFO = 2
        LEVEL_WARNING = 3
        LEVEL_ERROR = 4

        LEVEL_NAMES = containers.Map(...
            {1, 2, 3, 4}, ...
            {'DEBUG', 'INFO', 'WARNING', 'ERROR'})

        MIN_LOG_INTERVAL = 0.1  % Minimum time between identical log messages (seconds)
    end

    methods (Static)
        function logger = getLogger(name)
            % GETLOGGER Get or create a logger instance
            if nargin < 1
                name = 'DefaultLogger';
            end

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

    methods
        function obj = Logger(name)
            % Constructor
            if nargin < 1
                name = 'DefaultLogger';
            end

            if ~(ischar(name) || isstring(name))
                error('Logger:InvalidName', 'Logger name must be a string or character array');
            end

            obj.name = char(name);  % Convert to char array for consistency
            obj.logLevel = obj.LEVEL_INFO;
            obj.lastMessages = containers.Map();

            % Calculate UTC offset
            obj.utcOffset = getUTCOffset();

            % Get configuration
            try
                obj.config = config.getConfig().logging;
            catch ME
                warning('Logger:ConfigError', 'Failed to load logging configuration. Using defaults. Error: %s', ME.message);
                obj.config = struct('file_logging', true, ...
                    'console_logging', true, ...
                    'log_format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s');
            end

            % Initialize log file if enabled
            if obj.config.file_logging
                obj.initializeLogFile();
            end
        end

        function delete(obj)
            % Destructor - close log file if open
            if ~isempty(obj.logFile) && obj.logFile ~= -1
                fclose(obj.logFile);
            end
        end

        function setLevel(obj, level)
            % SETLEVEL Set the logging level
            if ischar(level) || isstring(level)
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

        function disp(obj)
            % Custom display method
            fprintf('  Logger Instance:\n');
            fprintf('    Name: %s\n', obj.name);
            fprintf('    Log Level: %s\n', obj.LEVEL_NAMES(obj.logLevel));
            fprintf('    File Logging: %s\n', mat2str(obj.config.file_logging));
            fprintf('    Console Logging: %s\n', mat2str(obj.config.console_logging));
            if ~isempty(obj.logFile) && obj.logFile ~= -1
                [~, logFileName, logFileExt] = fileparts(fopen(obj.logFile));
                fprintf('    Active Log File: %s%s\n', logFileName, logFileExt);
            end
        end

        function display(obj)
            % Custom display method for arrays
            if isscalar(obj)
                disp(obj);
            else
                fprintf('Array of %d Logger objects.\n', length(obj));
                for i = 1:length(obj)
                    fprintf('\nLogger %d:\n', i);
                    disp(obj(i));
                end
            end
        end
    end

    methods (Access = private)
        function initializeLogFile(obj)
            % Initialize log file with proper error handling
            try
                logDir = fullfile(pwd, 'logs');
                if ~exist(logDir, 'dir')
                    [success, msg] = mkdir(logDir);
                    if ~success
                        error('Failed to create log directory: %s', msg);
                    end
                end

                % Get current time in UTC
                utcTime = datetime('now') + hours(obj.utcOffset);
                timestamp = datestr(utcTime, 'yyyymmdd_HHMMSS');
                logPath = fullfile(logDir, sprintf('%s_%s.log', obj.name, timestamp));
                [obj.logFile, errmsg] = fopen(logPath, 'a');

                if obj.logFile == -1
                    error('Failed to open log file: %s', errmsg);
                end
            catch ME
                warning('Logger:FileError', 'Failed to initialize log file: %s', ME.message);
                obj.config.file_logging = false;
            end
        end

        function shouldLog = checkRateLimit(obj, level, message)
            % Rate limiting check for repeated messages
            currentTime = now;

            % Create unique key for level + message combination
            messageKey = sprintf('%d_%s', level, message);

            % Check if this is a new message
            if ~obj.lastMessages.isKey(messageKey)
                shouldLog = true;
                obj.lastMessages(messageKey) = struct('time', currentTime, 'count', 1);
                return;
            end

            % Get last message info
            lastMsg = obj.lastMessages(messageKey);
            timeDiff = (currentTime - lastMsg.time) * 86400; % Convert to seconds

            if timeDiff >= obj.MIN_LOG_INTERVAL
                shouldLog = true;
                obj.lastMessages(messageKey) = struct('time', currentTime, 'count', 1);
            else
                shouldLog = false;
                % Update repeat count
                lastMsg.count = lastMsg.count + 1;
                obj.lastMessages(messageKey) = lastMsg;
            end
        end

        function log(obj, level, message, varargin)
            % Internal logging method
            if level >= obj.logLevel && obj.checkRateLimit(level, message)
                try
                    % Format message
                    if ~isempty(varargin)
                        message = sprintf(message, varargin{:});
                    end

                    % Create log entry with UTC time
                    utcTime = datetime('now') + hours(obj.utcOffset);
                    timestamp = datestr(utcTime, 'yyyy-mm-dd HH:MM:SS.FFF');
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
                        % Check if file needs to be flushed
                        if mod(obj.lastMessages.length, 10) == 0
                            fflush(obj.logFile);
                        end
                    end
                catch ME
                    warning('Logger:LogError', 'Failed to log message: %s', ME.message);
                end
            end
        end
    end
end

% Helper function to calculate UTC offset
function offset = getUTCOffset()
% Get current time in local and UTC
localTime = datetime('now');
utcTime = datetime('now', 'TimeZone', 'UTC');

% Convert to same time zone for comparison
localInUTC = datetime(localTime, 'TimeZone', 'UTC');

% Calculate offset in hours
offset = hours(utcTime - localInUTC);
end