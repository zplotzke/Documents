classdef PlatoonTestSuite < matlab.unittest.TestCase
    % PLATOONTESTSUITE Test suite for truck platoon simulation
    %
    % Author: zplotzke
    % Last Modified: 2025-02-11 17:16:13 UTC
    % Version: 1.0.4

    properties
        tempLogDir  % Temporary directory for test logs
        logger      % Logger instance for test class
    end

    methods (TestClassSetup)
        function setupTestClass(testCase)
            % Create temporary directory for test logs
            testCase.tempLogDir = fullfile(tempdir, 'platoon_test_logs');
            if exist(testCase.tempLogDir, 'dir')
                rmdir(testCase.tempLogDir, 's');
            end
            mkdir(testCase.tempLogDir);

            % Ensure the directory exists before setting it
            testCase.verifyTrue(exist(testCase.tempLogDir, 'dir') == 7, ...
                'Failed to create temporary test directory');

            % Set log directory and verify
            utils.Logger.setLogDirectory(testCase.tempLogDir);

            % Initialize test logger
            testCase.logger = utils.Logger.getLogger('TestLogger');
        end
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            % Clear any existing log files before each test
            if exist(testCase.tempLogDir, 'dir')
                delete(fullfile(testCase.tempLogDir, '*.log'));
            end
        end
    end

    methods (TestClassTeardown)
        function teardownTestClass(testCase)
            % Clean up temporary log directory
            if exist(testCase.tempLogDir, 'dir')
                rmdir(testCase.tempLogDir, 's');
            end
        end
    end

    methods (Test)
        function testLoggerCreation(testCase)
            % Test logger creation and basic properties
            logger = utils.Logger('TestLogger');

            % Test log level constants
            testCase.verifyEqual(logger.LEVEL_NAMES(utils.Logger.LEVEL_INFO), 'INFO', ...
                'Default log level should be INFO');

            % Test config properties through disp output
            str = evalc('disp(logger)');
            testCase.verifyTrue(contains(str, 'Console Logging: true'), ...
                'Console logging should be enabled by default');
            testCase.verifyTrue(contains(str, 'File Logging: true'), ...
                'File logging should be enabled by default');
        end

        function testLogLevels(testCase)
            % Test different log levels
            logger = utils.Logger('LogLevelTest');

            % Test setting valid log levels
            validLevels = {'DEBUG', 'INFO', 'WARNING', 'ERROR'};
            levelConstants = [logger.LEVEL_DEBUG, logger.LEVEL_INFO, ...
                logger.LEVEL_WARNING, logger.LEVEL_ERROR];

            for i = 1:length(validLevels)
                logger.setLevel(validLevels{i});
                testCase.verifyEqual(logger.LEVEL_NAMES(levelConstants(i)), validLevels{i}, ...
                    sprintf('Failed to set log level to %s', validLevels{i}));
            end

            % Test invalid log level
            testCase.verifyError(@() logger.setLevel('INVALID'), ...
                'Logger:InvalidLevel');
        end

        function testFileLogging(testCase)
            % Test file logging functionality
            logger = utils.Logger('FileTest');
            testMessage = sprintf('Test message at UTC time: %s', ...
                datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

            % Log test message
            logger.info(testMessage);

            % Wait for filesystem
            pause(1.0);  % Increased pause time

            % Search for log files with pattern matching
            logPattern = fullfile(testCase.tempLogDir, 'FileTest_*.log');
            logFiles = dir(logPattern);

            % Verify file creation
            testCase.verifyNotEmpty(logFiles, sprintf('No log files found matching pattern: %s', logPattern));

            if ~isempty(logFiles)
                logPath = fullfile(logFiles(1).folder, logFiles(1).name);
                content = fileread(logPath);
                testCase.verifyTrue(contains(content, testMessage), ...
                    'Log file should contain test message');
            end
        end

        function testMessageFormatting(testCase)
            % Test message formatting with parameters
            logger = utils.Logger('FormatTest');
            testValue = 42;
            testStr = 'test';

            % Log formatted message
            logger.info('Value: %d, String: %s', testValue, testStr);

            % Wait for filesystem
            pause(1.0);  % Increased pause time

            % Search for log files
            logFiles = dir(fullfile(testCase.tempLogDir, 'FormatTest_*.log'));
            testCase.verifyNotEmpty(logFiles, 'Log file should be created');

            if ~isempty(logFiles)
                content = fileread(fullfile(logFiles(1).folder, logFiles(1).name));
                expectedMsg = sprintf('Value: %d, String: %s', testValue, testStr);
                testCase.verifyTrue(contains(content, expectedMsg), ...
                    'Log should contain formatted message');
            end
        end

        function testRateLimiting(testCase)
            % Test rate limiting functionality
            logger = utils.Logger('RateTest');
            testMessage = 'Rate limited message';

            % Send multiple messages quickly
            for i = 1:5
                logger.info(testMessage);
            end

            % Wait for rate limit interval plus buffer
            pause(utils.Logger.MIN_LOG_INTERVAL + 1.0);

            % Send another message
            logger.info(testMessage);

            % Wait for filesystem
            pause(1.0);

            % Search for log files
            logFiles = dir(fullfile(testCase.tempLogDir, 'RateTest_*.log'));
            testCase.verifyNotEmpty(logFiles, 'Log file should be created');

            if ~isempty(logFiles)
                content = fileread(fullfile(logFiles(1).folder, logFiles(1).name));
                matches = regexp(content, testMessage, 'match');
                testCase.verifyTrue(length(matches) < 5, ...
                    'Rate limiting should prevent all messages from being logged');
            end
        end

        function testLoggerSingleton(testCase)
            % Test logger singleton pattern
            logger1 = utils.Logger.getLogger('SingletonTest');
            logger2 = utils.Logger.getLogger('SingletonTest');

            % Verify same instance
            testCase.verifyTrue(isequal(logger1, logger2), ...
                'getLogger should return same instance for same name');
        end

        function testCustomLogDir(testCase)
            % Test custom log directory
            customDir = fullfile(testCase.tempLogDir, 'custom_logs');

            % Create custom directory
            if ~exist(customDir, 'dir')
                mkdir(customDir);
            end

            % Set and verify custom directory
            utils.Logger.setLogDirectory(customDir);

            % Create logger and log message
            logger = utils.Logger('CustomDirTest');
            logger.info('Test message');

            % Wait for filesystem
            pause(1.0);

            % Search for log files in custom directory
            logPattern = fullfile(customDir, 'CustomDirTest_*.log');
            logFiles = dir(logPattern);

            % Verify file creation in custom directory
            testCase.verifyNotEmpty(logFiles, ...
                sprintf('No log files found in custom directory matching pattern: %s', logPattern));
        end
    end
end