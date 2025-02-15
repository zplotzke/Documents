classdef Logger < handle
    % LOGGER Logging utility for truck platoon simulation
    %
    % Author: zplotzke
    % Last Modified: 2025-02-15 04:22:51 UTC
    % Version: 1.1.6

    properties (Constant)
        DEBUG = 1
        INFO = 2
        WARNING = 3
        ERROR = 4

        LEVEL_NAMES = containers.Map(...
            {1, 2, 3, 4}, ...
            {'DEBUG', 'INFO', 'WARNING', 'ERROR'})
    end

    properties
        level         % Current log level - Changed to allow public access
    end

    properties (SetAccess = private, GetAccess = public)
        name           % Logger name
    end

    properties (Access = private)
        logFile        % File handle for logging
        config        % Logger configuration
        currentLogPath % Current log file path
        logDir        % Directory for log files
        fileLogging = false    % File logging state
        consoleLogging = true  % Console logging state
    end

    methods
        function obj = Logger(name, logDir)
            % Get configuration first
            obj.config = config.getConfig();

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
            obj.logDir = logDir;
            obj.level = obj.INFO;  % Default log level
            obj.logFile = -1;

            obj.info('Logger initialized by %s', getenv('USERNAME'));
        end

        function delete(obj)
            % Destructor - close log file if open
            if ~isempty(obj.logFile) && obj.logFile ~= -1
                fclose(obj.logFile);
            end
        end

        function enableFileLogging(obj, filename)
            % Enable logging to file
            if ~ischar(filename) || isempty(filename)
                error('Logger:ArgumentError', 'Filename must be non-empty string');
            end

            % Close existing file if open
            if obj.logFile ~= -1
                fclose(obj.logFile);
            end

            % Create directory if it doesn't exist
            [fpath, ~, ~] = fileparts(filename);
            if ~isempty(fpath) && ~exist(fpath, 'dir')
                mkdir(fpath);
            end

            % Open new file
            obj.logFile = fopen(filename, 'a');
            if obj.logFile < 0
                error('Logger:FileError', 'Could not open log file: %s', filename);
            end
            obj.currentLogPath = filename;
            obj.fileLogging = true;
            obj.debug('File logging enabled: %s', filename);
        end

        function disableFileLogging(obj)
            % Disable logging to file
            if obj.logFile ~= -1
                fclose(obj.logFile);
                obj.logFile = -1;
                obj.fileLogging = false;
                obj.debug('File logging disabled');
            end
        end

        function setFileLogging(obj, enable)
            if enable && ~obj.fileLogging
                obj.enableFileLogging(fullfile(obj.logDir, [obj.name '_' datestr(now, 'yyyymmdd') '.log']));
            elseif ~enable && obj.fileLogging
                obj.disableFileLogging();
            end
        end

        function setConsoleLogging(obj, enable)
            obj.consoleLogging = enable;
        end

        function [fileLogging, consoleLogging] = getLoggingConfig(obj)
            fileLogging = obj.fileLogging;
            consoleLogging = obj.consoleLogging;
        end

        function setLevel(obj, level)
            if ischar(level) || isstring(level)
                level = upper(char(level));
                switch level
                    case 'DEBUG'
                        obj.level = obj.DEBUG;
                    case 'INFO'
                        obj.level = obj.INFO;
                    case 'WARNING'
                        obj.level = obj.WARNING;
                    case 'ERROR'
                        obj.level = obj.ERROR;
                    otherwise
                        error('Logger:InvalidLevel', 'Invalid log level: %s', level);
                end
            elseif isnumeric(level)
                if ~ismember(level, [obj.DEBUG, obj.INFO, obj.WARNING, obj.ERROR])
                    error('Logger:InvalidLevel', 'Invalid numeric level: %d', level);
                end
                obj.level = level;
            else
                error('Logger:InvalidLevel', 'Level must be string or numeric');
            end
        end

        function debug(obj, msg, varargin)
            obj.log(obj.DEBUG, msg, varargin{:});
        end

        function info(obj, msg, varargin)
            obj.log(obj.INFO, msg, varargin{:});
        end

        function warning(obj, msg, varargin)
            obj.log(obj.WARNING, msg, varargin{:});
        end

        function error(obj, msg, varargin)
            obj.log(obj.ERROR, msg, varargin{:});
        end

        function display(obj)
            % Custom display method
            fprintf('\nLogger Instance:\n');
            fprintf('  Name: %s\n', obj.name);
            fprintf('  Log Level: %s\n', obj.LEVEL_NAMES(obj.level));
            fprintf('  File Logging: %s\n', mat2str(obj.fileLogging));
            fprintf('  Console Logging: %s\n', mat2str(obj.consoleLogging));
            if obj.fileLogging
                fprintf('  Current Log File: %s\n', obj.currentLogPath);
            end
            fprintf('\n');
        end
    end

    methods (Access = private)
        function log(obj, level, msg, varargin)
            % Internal logging function
            if level >= obj.level
                if ~isempty(varargin)
                    msg = sprintf(msg, varargin{:});
                end

                % Format the log entry
                timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
                entry = sprintf('%s [%s] %s: %s\n', ...
                    timestamp, ...
                    obj.LEVEL_NAMES(level), ...
                    obj.name, ...
                    msg);

                % Write to console if enabled
                if obj.consoleLogging
                    if level >= obj.WARNING
                        fprintf(2, '%s', entry);  % Use stderr for warnings/errors
                    else
                        fprintf(1, '%s', entry);  % Use stdout for info/debug
                    end
                end

                % Write to file if enabled
                if obj.fileLogging && obj.logFile ~= -1
                    fprintf(obj.logFile, '%s', entry);
                end
            end
        end
    end

    methods (Static)
        function logger = getLogger(name, logDir)
            persistent loggers
            if isempty(loggers)
                loggers = containers.Map();
            end

            if nargin < 1 || isempty(name)
                name = 'DefaultLogger';
            end

            % Create unique key for logger instance
            if nargin < 2
                logDir = fullfile(pwd, 'logs');
            end
            loggerKey = sprintf('%s_%s', name, logDir);

            if ~loggers.isKey(loggerKey)
                loggers(loggerKey) = utils.Logger(name, logDir);
            end
            logger = loggers(loggerKey);
        end
    end
end