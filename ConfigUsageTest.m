classdef ConfigUsageTest < matlab.unittest.TestCase
    % CONFIGUSAGETEST Validates consistent configuration usage patterns
    %
    % Tests that all files follow these configuration best practices:
    % 1. Config is obtained early in class initialization
    % 2. Config is stored as a property when needed multiple times
    % 3. Config is passed as parameter rather than re-fetched
    % 4. No direct modification of config values
    %
    % Author: zplotzke
    % Last Modified: 2025-02-15 03:18:39 UTC
    % Version: 1.0.0
    
    properties
        sourceFiles  % List of MATLAB files to check
    end
    
    methods (TestMethodSetup)
        function setupTest(testCase)
            % Get all MATLAB files in project
            testCase.sourceFiles = dir('**/*.m');
        end
    end
    
    methods (Test)
        function testConfigInitialization(testCase)
            % Test that config is obtained in constructor/initialization
            for i = 1:length(testCase.sourceFiles)
                file = testCase.sourceFiles(i);
                if ~contains(file.name, {'ConfigTest', 'ConfigUsageTest'})
                    content = fileread(fullfile(file.folder, file.name));
                    
                    % Check if file contains config.getConfig()
                    if contains(content, 'config.getConfig')
                        % Verify it's called in constructor or initialization
                        hasConstructor = contains(content, 'function obj =');
                        if hasConstructor
                            testCase.verifyTrue(...
                                contains(content, 'obj.config = config.getConfig'), ...
                                sprintf('Config should be stored in constructor: %s', file.name));
                        end
                    end
                end
            end
        end
        
        function testConfigStorage(testCase)
            % Test that config is stored as property when used multiple times
            for i = 1:length(testCase.sourceFiles)
                file = testCase.sourceFiles(i);
                if ~contains(file.name, {'ConfigTest', 'ConfigUsageTest'})
                    content = fileread(fullfile(file.folder, file.name));
                    
                    % Count config.getConfig() calls
                    configCalls = count(content, 'config.getConfig');
                    if configCalls > 1
                        % Should be stored as property
                        testCase.verifyTrue(...
                            contains(content, 'properties') && ...
                            contains(content, 'config'), ...
                            sprintf('Multiple config uses should store as property: %s', file.name));
                    end
                end
            end
        end
        
        function testConfigPassing(testCase)
            % Test that config is passed rather than re-fetched
            for i = 1:length(testCase.sourceFiles)
                file = testCase.sourceFiles(i);
                if ~contains(file.name, {'ConfigTest', 'ConfigUsageTest'})
                    content = fileread(fullfile(file.folder, file.name));
                    
                    % Check function definitions for config parameter
                    if contains(content, 'function') && contains(content, 'config.getConfig')
                        lines = regexp(content, '\n', 'split');
                        for j = 1:length(lines)
                            if contains(lines{j}, 'function') && ~contains(lines{j}, 'obj =')
                                testCase.verifyTrue(...
                                    contains(lines{j}, 'config'), ...
                                    sprintf('Functions should accept config as parameter: %s', file.name));
                            end
                        end
                    end
                end
            end
        end
        
        function testConfigModification(testCase)
            % Test that config is not modified directly
            for i = 1:length(testCase.sourceFiles)
                file = testCase.sourceFiles(i);
                if ~contains(file.name, {'ConfigTest', 'ConfigUsageTest'})
                    content = fileread(fullfile(file.folder, file.name));
                    
                    % Look for direct config modifications
                    if contains(content, 'config.getConfig')
                        testCase.verifyFalse(...
                            contains(content, 'config = ') || ...
                            contains(content, 'config.simulation = ') || ...
                            contains(content, 'config.truck = '), ...
                            sprintf('Config should not be modified directly: %s', file.name));
                    end
                end
            end
        end
    end
end