% STARTUP Add truck platoon packages to MATLAB path
%
% Initializes the truck platoon simulation environment by adding all required
% package directories to the MATLAB path.
%
% Author: zplotzke
% Last Modified: 2025-02-11 15:05:39 UTC
% Version: 1.0.0

try
    % Get the directory containing this startup file
    rootDir = fileparts(mfilename('fullpath'));

    % Add package directories to path
    addpath(rootDir);
    addpath(genpath(fullfile(rootDir, '+config')));
    addpath(genpath(fullfile(rootDir, '+utils')));
    addpath(genpath(fullfile(rootDir, '+core')));
    addpath(genpath(fullfile(rootDir, '+viz')));
    addpath(genpath(fullfile(rootDir, '+ml')));
    addpath(genpath(fullfile(rootDir, 'tests')));

    % Create required directories if they don't exist
    requiredDirs = {'data', 'logs', 'results', 'models'};
    for i = 1:length(requiredDirs)
        dirPath = fullfile(rootDir, requiredDirs{i});
        if ~exist(dirPath, 'dir')
            mkdir(dirPath);
            fprintf('Created directory: %s\n', requiredDirs{i});
        end
    end

    % Display startup message
    fprintf('\nTruck Platoon Simulation Environment\n');
    fprintf('Initialization completed successfully\n');
    fprintf('Timestamp: %s\n', '2025-02-11 15:05:39 UTC');
    fprintf('Author: %s\n', 'zplotzke');
    fprintf('Environment ready for simulation\n\n');

catch ME
    fprintf(2, 'Error during startup:\n%s\n', ME.message);
    fprintf(2, 'Stack trace:\n%s\n', getReport(ME));
end