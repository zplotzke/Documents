classdef Logger < handle
    % LOGGER Simple logging utility class
    %
    % Author: zplotzke
    % Created: 2025-02-08 03:48:47 UTC

    properties (Access = private)
        name        % Logger name
        logLevel    % Current log level
    end

    properties (Constant, Access = private)
        % Log levels
        LEVEL_DEBUG = 1;
        LEVEL_INFO = 2;
        LEVEL_WARNING = 3;
        LEVEL_ERROR = 4;
    end

    methods (Static)
        function logger = getLogger(name)
            % GETLOGGER Create or get a logger instance
            % name: String identifier for the logger
            persistent loggers
            if isempty(loggers)
                loggers = containers.Map();
            end

            if ~loggers.isKey(name)
                loggers(name) = Logger(name);
            end
            logger = loggers(name);
        end
    end

    methods (Access = private)
        function obj = Logger(name)
            % Constructor is private to enforce singleton pattern
            obj.name = name;
            obj.logLevel = obj.LEVEL_INFO;  % Default to INFO level
        end
    end

    methods
        function debug(obj, message, varargin)
            if obj.logLevel <= obj.LEVEL_DEBUG
                obj.log('DEBUG', message, varargin{:});
            end
        end

        function info(obj, message, varargin)
            if obj.logLevel <= obj.LEVEL_INFO
                obj.log('INFO', message, varargin{:});
            end
        end

        function warning(obj, message, varargin)
            if obj.logLevel <= obj.LEVEL_WARNING
                obj.log('WARNING', message, varargin{:});
            end
        end

        function error(obj, message, varargin)
            if obj.logLevel <= obj.LEVEL_ERROR
                obj.log('ERROR', message, varargin{:});
            end
        end
    end

    methods (Access = private)
        function log(obj, level, message, varargin)
            % Internal logging function
            timestamp = datestr(now, 'dd-mmm-yyyy HH:MM:SS');  % Changed to match output format
            if isempty(varargin)
                formatted_message = message;
            else
                formatted_message = sprintf(message, varargin{:});
            end
            fprintf('%s [%s] %s\n', timestamp, level, formatted_message);
        end
    end
end