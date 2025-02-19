classdef SonificatorTest < matlab.unittest.TestCase
    % SONIFICATORTEST Test cases for utils.Sonificator class
    %
    % Author: zplotzke
    % Last Modified: 2025-02-19 15:09:51 UTC
    % Version: 1.0.1
    
    properties
        sonificator
    end
    
    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.sonificator = utils.Sonificator();  % Updated to use package reference
        end
    end
    
    methods (Test)
        function testEnableDisable(testCase)
            % Test enable/disable functionality
            testCase.sonificator.disable();
            testCase.verifyFalse(testCase.sonificator.getEnabled(), ...
                'Sonificator should be disabled');

            testCase.sonificator.enable();
            testCase.verifyTrue(testCase.sonificator.getEnabled(), ...
                'Sonificator should be enabled');
        end
        
        function testWarningTypes(testCase)
            % Test all warning types
            warningTypes = {'COLLISION', 'EMERGENCY_BRAKE', 'DISTANCE', 'SPEED'};
            for i = 1:length(warningTypes)
                testCase.sonificator.sonifyWarning(warningTypes{i}, 0.5);
                pause(0.5); % Allow time between sounds
            end
            testCase.verifyTrue(true);
        end
        
        function testSeverityLevels(testCase)
            % Test different severity levels
            severityLevels = [0.0, 0.3, 0.7, 1.0];
            for i = 1:length(severityLevels)
                testCase.sonificator.sonifyWarning('COLLISION', severityLevels(i));
                pause(0.5);
            end
            testCase.verifyTrue(true);
        end
        
        function testRapidWarnings(testCase)
            % Test handling of rapid warning sequences
            for i = 1:5
                testCase.sonificator.sonifyWarning('COLLISION', 1.0);
                pause(0.1); % Try to trigger warnings faster than minimum interval
            end
            testCase.verifyTrue(true);
        end
        
        function testPackageIntegration(testCase)
            % Test that the class is properly accessible via the utils package
            testCase.verifyTrue(isa(testCase.sonificator, 'utils.Sonificator'), ...
                'Sonificator should be in utils package');
        end
    end
end