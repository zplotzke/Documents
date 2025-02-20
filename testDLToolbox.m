function results = testDLToolbox()
% TESTDLTOOLBOX Test if Deep Learning Toolbox is functioning properly
%
% Author: zplotzke
% Last Modified: 2025-02-19 17:33:12 UTC
% Version: 1.0.0

% Initialize results
results = struct();

try
    % Test 1: Check if toolbox is installed
    results.toolbox_installed = false;
    if ~isempty(ver('deep'))
        results.toolbox_installed = true;
        results.toolbox_version = ver('deep');
    else
        error('testDLToolbox:MissingToolbox', ...
            'Deep Learning Toolbox is not installed');
    end
    
    % Test 2: Create a simple LSTM network
    numFeatures = 4;
    numHiddenUnits = 10;
    
    layers = [ ...
        sequenceInputLayer(numFeatures)
        lstmLayer(numHiddenUnits)
        fullyConnectedLayer(numFeatures)
        regressionLayer];
    
    % Test 3: Create and process sample data
    numTimeSteps = 5;
    numObservations = 1;
    X = rand(numTimeSteps, numFeatures, numObservations);
    
    % Try to create the network
    options = trainingOptions('adam', ...
        'MaxEpochs', 1, ...
        'Verbose', false);
        
    try
        net = trainNetwork(X, X, layers, options);
        results.network_creation = 'passed';
        
        % Try a prediction
        Y = predict(net, X);
        results.prediction = 'passed';
        results.prediction_size = size(Y);
        
    catch ME
        results.network_creation = 'failed';
        results.error = ME.message;
    end
    
    % Overall status
    results.status = 'passed';
    
catch ME
    results.status = 'failed';
    results.error = ME.message;
    rethrow(ME);
end

end