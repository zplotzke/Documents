classdef LoggerTest < matlab.unittest.TestCase
    % LOGGERTEST Test suite for Logger.m
    %
    % Test suite for verifying Logger functionality including file handling,
    % log levels, message formatting, and configuration options.
    %
    % Author: zplotzke
    % Last Modified: 2025-02-11 20:41:21 UTC
    % Version: 1.0.0

    properties (TestParameter)
        LogLevel = {'DEBUG', 'INFO', 'WARNING', 'ERROR'}
        LoggerName = {'TestLogger1', 'TestLogger2', 'TestLogger3'}
    end

    properties
        tempLogDir  % Temporary directory for test logs
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            % Create temporary log directory for tests
            testCase.tempLogDir = fullfile(tempdir, ['logger_test_' char(java.util.UUID.randomUUID)]);
            if ~exist(testCase.tempLogDir, 'dir')
                mkdir(testCase.tempLogDir);
            end
        end
    end

    methods (TestMethodTeardown)
        function teardownMethod(testCase)
            % Clean up files after each test
            if exist(testCase.tempLogDir, 'dir')
                files = dir(fullfile(testCase.tempLogDir, '*.log'));
                for i = 1:length(files)
                    filepath = fullfile(testCase.tempLogDir, files(i).name);
                    if exist(filepath, 'file')
                        % Close any open file handles first
                        fclose('all');  % Close all open files
                        try
                            % Use Java file deletion as a fallback if MATLAB delete fails
                            if ~delete(filepath)
                                jFile = java.io.File(filepath);
                                jFile.delete();
                            end
                        catch
                            % If both deletion methods fail, ignore and continue
                        end
                    end
                end
            end
        end
    end

    methods (TestClassTeardown)
        function teardownClass(testCase)
            % Remove test directory
            if exist(testCase.tempLogDir, 'dir')
                % Close all open files first
                fclose('all');

                % Wait for file system
                pause(0.1);

                try
                    % First try MATLAB's rmdir
                    rmdir(testCase.tempLogDir, 's');
                catch
                    try
                        % If MATLAB's rmdir fails, try Java's file deletion
                        jFile = java.io.File(testCase.tempLogDir);
                        javaFiles = jFile.listFiles();
                        for i = 1:length(javaFiles)
                            javaFiles(i).delete();
                        end
                        jFile.delete();
                    catch ME
                        warning('Failed to remove test directory: %s', ME.message);
                    end
                end
            end
        end
    end

    methods (Test)
        function testLoggerCreation(testCase)
            % Test logger creation and singleton pattern
            logger1 = utils.Logger.getLogger('SingletonTest', testCase.tempLogDir);
            logger2 = utils.Logger.getLogger('SingletonTest', testCase.tempLogDir);

            testCase.verifyEqual(logger1, logger2, ...
                'Logger singleton pattern failed');
        end

        function testDefaultLogger(testCase)
            % Test default logger creation
            logger = utils.Logger.getLogger('', testCase.tempLogDir);

            testCase.verifyEqual(logger.name, 'DefaultLogger', ...
                'Default logger name mismatch');
            testCase.verifyEqual(logger.logLevel, logger.LEVEL_INFO, ...
                'Default log level mismatch');

            % Verify default configuration
            [fileLogging, consoleLogging] = logger.getLoggingConfig();
            testCase.verifyFalse(fileLogging, 'File logging should be disabled by default');
            testCase.verifyTrue(consoleLogging, 'Console logging should be enabled by default');
        end

        function testLogLevels(testCase, LogLevel)
            % Test setting and verifying log levels
            logger = utils.Logger.getLogger('LevelTest', testCase.tempLogDir);
            logger.setLevel(LogLevel);

            expectedLevel = logger.(['LEVEL_' LogLevel]);
            testCase.verifyEqual(logger.logLevel, expectedLevel, ...
                sprintf('Failed to set log level to %s', LogLevel));
        end

        function testInvalidLogLevel(testCase)
            % Test invalid log level handling
            logger = utils.Logger.getLogger('InvalidTest', testCase.tempLogDir);

            testCase.verifyError(@() logger.setLevel('INVALID'), ...
                'Logger:InvalidLevel');
            testCase.verifyError(@() logger.setLevel(123), ...
                'Logger:InvalidLevel');
        end

        function testMessageLogging(testCase)
            % Test message logging at different levels
            logger = utils.Logger.getLogger('MessageTest', testCase.tempLogDir);
            logger.setFileLogging(true);  % Enable file logging for this test

            % Test messages
            debugMsg = 'Debug message';
            infoMsg = 'Info message';
            warnMsg = 'Warning message';
            errorMsg = 'Error message';

            % Log messages
            logger.debug(debugMsg);
            logger.info(infoMsg);
            logger.warning(warnMsg);
            logger.error(errorMsg);

            % Allow time for file system
            pause(0.1);

            % Verify log file contents
            files = dir(fullfile(testCase.tempLogDir, 'MessageTest_*.log'));
            testCase.verifyNotEmpty(files, 'Log file not created');

            if ~isempty(files)
                content = fileread(fullfile(files(1).folder, files(1).name));

                % Default level is INFO, so debug message should not appear
                testCase.verifyFalse(contains(content, debugMsg), ...
                    'Debug message should not appear at INFO level');

                % Other messages should appear
                testCase.verifyTrue(contains(content, infoMsg), ...
                    'Info message not found in log');
                testCase.verifyTrue(contains(content, warnMsg), ...
                    'Warning message not found in log');
                testCase.verifyTrue(contains(content, errorMsg), ...
                    'Error message not found in log');
            end
        end

        function testFormattedMessages(testCase)
            % Test formatted message logging
            logger = utils.Logger.getLogger('FormatTest', testCase.tempLogDir);
            logger.setFileLogging(true);  % Enable file logging for this test

            % Test various format types
            intValue = 42;
            strValue = 'test';
            floatValue = 3.14159;

            message = sprintf('Values: %d, %s, %.2f', intValue, strValue, floatValue);
            logger.info('Values: %d, %s, %.2f', intValue, strValue, floatValue);

            % Allow time for file system
            pause(0.1);

            % Verify log file contains formatted message
            files = dir(fullfile(testCase.tempLogDir, 'FormatTest_*.log'));
            testCase.verifyNotEmpty(files, 'Log file not created');

            if ~isempty(files)
                content = fileread(fullfile(files(1).folder, files(1).name));
                testCase.verifyTrue(contains(content, message), ...
                    'Formatted message not found in log');
            end
        end

        function testLoggerDisplay(testCase)
            % Test logger display formatting
            logger = utils.Logger.getLogger('DisplayTest', testCase.tempLogDir);
            logger.setFileLogging(true);  % Enable file logging for display test

            % Capture display output
            str = evalc('disp(logger)');

            % Verify display format
            testCase.verifyTrue(contains(str, 'Logger Instance'), ...
                'Logger display missing header');
            testCase.verifyTrue(contains(str, 'Name: DisplayTest'), ...
                'Logger display missing name');
            testCase.verifyTrue(contains(str, 'Log Level: INFO'), ...
                'Logger display missing level');
            testCase.verifyTrue(contains(str, 'File Logging: true'), ...
                'Logger display missing file logging state');
            testCase.verifyTrue(contains(str, 'Console Logging: true'), ...
                'Logger display missing console logging state');
        end

        function testFileCreation(testCase, LoggerName)
            % Test log file creation and writing
            logger = utils.Logger.getLogger(LoggerName, testCase.tempLogDir);
            logger.setFileLogging(true);  % Enable file logging for this test

            testMessage = sprintf('Test message from %s', LoggerName);
            logger.info(testMessage);

            % Allow time for file system
            pause(0.1);

            % Verify log file exists and contains message
            files = dir(fullfile(testCase.tempLogDir, [LoggerName '_*.log']));
            testCase.verifyNotEmpty(files, ...
                sprintf('Log file not created for %s', LoggerName));

            if ~isempty(files)
                content = fileread(fullfile(files(1).folder, files(1).name));
                testCase.verifyTrue(contains(content, testMessage), ...
                    'Test message not found in log file');
            end
        end

        function testMultipleLoggers(testCase)
            % Test multiple loggers operating independently
            logger1 = utils.Logger.getLogger('MultiTest1', testCase.tempLogDir);
            logger2 = utils.Logger.getLogger('MultiTest2', testCase.tempLogDir);

            % Set different levels and enable file logging
            logger1.setFileLogging(true);
            logger2.setFileLogging(true);
            logger1.setLevel('DEBUG');
            logger2.setLevel('ERROR');

            % Log messages
            msg1 = 'Debug message from logger1';
            msg2 = 'Error message from logger2';

            logger1.debug(msg1);
            logger2.debug('This should not appear');
            logger2.error(msg2);

            % Allow time for file system
            pause(0.1);

            % Verify logger1 file
            files1 = dir(fullfile(testCase.tempLogDir, 'MultiTest1_*.log'));
            testCase.verifyNotEmpty(files1, 'Logger1 file not created');

            if ~isempty(files1)
                content = fileread(fullfile(files1(1).folder, files1(1).name));
                testCase.verifyTrue(contains(content, msg1), ...
                    'Logger1 message not found');
            end

            % Verify logger2 file
            files2 = dir(fullfile(testCase.tempLogDir, 'MultiTest2_*.log'));
            testCase.verifyNotEmpty(files2, 'Logger2 file not created');

            if ~isempty(files2)
                content = fileread(fullfile(files2(1).folder, files2(1).name));
                testCase.verifyTrue(contains(content, msg2), ...
                    'Logger2 error message not found');
                testCase.verifyFalse(contains(content, 'This should not appear'), ...
                    'Logger2 debug message should not appear');
            end
        end

        function testConfigOverride(testCase)
            % Test logger with configuration overrides
            logger = utils.Logger.getLogger('ConfigTest', testCase.tempLogDir);

            % Test console-only logging (file logging should be off by default)
            testMsg = 'Console only message';
            logger.info(testMsg);

            % Allow time for file system
            pause(0.1);

            % Verify no log file was created
            files = dir(fullfile(testCase.tempLogDir, 'ConfigTest_*.log'));
            testCase.verifyEmpty(files, 'Log file should not be created when file logging is disabled');

            % Test file-only logging with new logger instance
            logger2 = utils.Logger.getLogger('ConfigTest2', testCase.tempLogDir);
            logger2.setConsoleLogging(false);
            logger2.setFileLogging(true);

            testMsg = 'File only message';
            logger2.info(testMsg);

            % Allow time for file system
            pause(0.1);

            % Verify log file was created and contains message
            files = dir(fullfile(testCase.tempLogDir, 'ConfigTest2_*.log'));
            testCase.verifyNotEmpty(files, 'Log file not created when file logging is enabled');

            if ~isempty(files)
                content = fileread(fullfile(files(1).folder, files(1).name));
                testCase.verifyTrue(contains(content, testMsg), ...
                    'Message not found in log file');
            end

            % Verify configuration getters
            [fileLogging, consoleLogging] = logger2.getLoggingConfig();
            testCase.verifyTrue(fileLogging, 'File logging should be enabled');
            testCase.verifyFalse(consoleLogging, 'Console logging should be disabled');
        end
    end
end