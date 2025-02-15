classdef LoggerTest < matlab.unittest.TestCase
    % LOGGERTEST Basic tests for Logger class
    %
    % Author: zplotzke
    % Last Modified: 2025-02-15 03:49:37 UTC

    properties
        logger
        logFile
    end

    methods (TestMethodSetup)
        function setup(testCase)
            testCase.logger = utils.Logger('TestLogger');
            testCase.logFile = [tempname '.log'];
        end
    end

    methods (TestMethodTeardown)
        function cleanup(testCase)
            testCase.logger.disableFileLogging();
            delete(testCase.logger);
            testCase.logger = [];

            if exist(testCase.logFile, 'file')
                try
                    delete(testCase.logFile);
                catch
                    % Ignore deletion errors in cleanup
                end
            end
        end
    end

    methods (Test)
        function testBasicLogging(testCase)
            testCase.logger.info('Test message');
            testCase.verifyTrue(true, 'Console logging should not error');

            testCase.logger.enableFileLogging(testCase.logFile);
            testCase.logger.info('File test');
            testCase.verifyTrue(exist(testCase.logFile, 'file') == 2, ...
                'Log file should exist');
        end

        function testLogLevels(testCase)
            testCase.logger.level = testCase.logger.ERROR;
            testCase.logger.info('Should not appear');
            testCase.logger.error('Should appear');
            testCase.verifyTrue(true, 'Level filtering should work');
        end
    end
end