function results = diagnoseDLToolbox()
% DIAGNOSEDLTOOLBOX Detailed diagnosis of Deep Learning Toolbox installation
%
% Author: zplotzke
% Last Modified: 2025-02-19 17:38:15 UTC
% Version: 1.0.0

% Initialize logger for detailed output
results = struct();
fprintf('Starting Deep Learning Toolbox diagnosis at %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

% Step 1: Check toolbox using ver command
fprintf('\nStep 1: Checking toolbox using ver command\n');
v = ver('deep');
if ~isempty(v)
    fprintf('Found Deep Learning Toolbox:\n');
    fprintf('- Version: %s\n', v.Version);
    fprintf('- Release: %s\n', v.Release);
    fprintf('- Date: %s\n', v.Date);
    results.ver_check = 'passed';
else
    fprintf('WARNING: ver(''deep'') returned empty\n');
    results.ver_check = 'failed';
end

% Step 2: Check specific functions
fprintf('\nStep 2: Checking key functions\n');
functions_to_check = {'sequenceInputLayer', 'lstmLayer', 'trainNetwork', 'predict'};
results.missing_functions = {};

for i = 1:length(functions_to_check)
    func = functions_to_check{i};
    if exist(func, 'file') == 2
        fprintf('- %s: Available\n', func);
    else
        fprintf('WARNING: %s not found\n', func);
        results.missing_functions{end+1} = func;
    end
end

% Step 3: Check license
fprintf('\nStep 3: Checking license\n');
if license('test', 'Neural_Network_Toolbox')
    fprintf('Neural Network Toolbox license: Valid\n');
    results.license_check = 'passed';
else
    fprintf('WARNING: Neural Network Toolbox license not found\n');
    results.license_check = 'failed';
end

% Step 4: Try to create a minimal network
fprintf('\nStep 4: Testing minimal network creation\n');
try
    layers = [ ...
        sequenceInputLayer(1)
        lstmLayer(1)
        fullyConnectedLayer(1)
        regressionLayer];
    fprintf('Successfully created minimal layer structure\n');
    results.network_creation = 'passed';
catch ME
    fprintf('ERROR creating network: %s\n', ME.message);
    results.network_creation = 'failed';
    results.network_error = ME.message;
end

% Step 5: Check path
fprintf('\nStep 5: Checking toolbox path\n');
toolboxPath = matlabroot;
deepLearningPath = fullfile(toolboxPath, 'toolbox', 'nnet');
if exist(deepLearningPath, 'dir')
    fprintf('Deep Learning Toolbox path exists: %s\n', deepLearningPath);
    results.path_check = 'passed';
else
    fprintf('WARNING: Deep Learning Toolbox path not found at expected location\n');
    results.path_check = 'failed';
end

% Final status
if isfield(results, 'network_creation') && strcmp(results.network_creation, 'passed')
    results.status = 'operational';
else
    results.status = 'issues_detected';
end

fprintf('\nDiagnosis complete. Status: %s\n', results.status);
end