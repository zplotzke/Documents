function tests = testLogger

tests = functiontests(localfunctions);
end

function testLoggerSingleton(testCase)
% Test that getLogger returns same instance for same name
logger1 = Logger.getLogger('TestLogger');
logger2 = Logger.getLogger('TestLogger');
verifyEqual(testCase, logger1, logger2);

% Test that different names get different instances
logger3 = Logger.getLogger('DifferentLogger');
verifyNotEqual(testCase, logger1, logger3);
end

function testLogLevels(testCase)
logger = Logger.getLogger('TestLogLevels');

% Test logging at different levels
logger.debug('Debug message');
logger.info('Info message');
logger.warning('Warning message');
logger.error('Error message');

% Note: Since Logger writes to stdout, we can't easily verify output
% In a more sophisticated test, we might want to redirect stdout
% or modify Logger to allow output capture for testing
end

function testMessageFormatting(testCase)
logger = Logger.getLogger('TestFormatting');

% Test formatted messages
logger.info('Test %s %d', 'number', 42);
logger.error('Error code: %d', 404);
end