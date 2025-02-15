% STARTUP Add truck platoon packages to MATLAB path
%
% Initializes the truck platoon simulation environment by adding all required
% package directories to the MATLAB path.
%
% Author: zplotzke
% Last Modified: 2025-02-15 05:19:52 UTC
% Version: 1.0.2

try
    % Get the directory containing this startup file
    rootDir = fileparts(mfilename('fullpath'));

    % Only add the root directory to the path
    % MATLAB will automatically handle the package directories
    addpath(rootDir);
    addpath(fullfile(rootDir, 'tests'));

    % Create required directories if they don't exist
    requiredDirs = {'data', 'logs', 'results', 'models', ...
        '+config', '+core', '+utils', '+ml', 'tests'};

    for i = 1:length(requiredDirs)
        dirPath = fullfile(rootDir, requiredDirs{i});
        if ~exist(dirPath, 'dir')
            [success, msg] = mkdir(dirPath);
            if ~success
                warning('Failed to create directory %s: %s', requiredDirs{i}, msg);
            else
                fprintf('Created directory: %s\n', requiredDirs{i});
            end
        end
    end

    % Display startup message
    fprintf('\nTruck Platoon Simulation Environment\n');
    fprintf('Initialization completed successfully\n');
    fprintf('Timestamp: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf('Author: %s\n', 'zplotzke');
    fprintf('Environment ready for simulation\n\n');

catch ME
    fprintf(2, 'Error during startup:\n%s\n', ME.message);
    fprintf(2, 'Stack trace:\n%s\n', getReport(ME));
end