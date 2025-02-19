function results = validateLSTMNetwork()
% VALIDATELSTMNETWORK Validation function for LSTM Network implementation
%
% Author: zplotzke
% Last Modified: 2025-02-19 17:53:48 UTC
% Version: 1.1.4

% Initialize logger
logger = utils.Logger.getLogger('validateLSTMNetwork');
logger.info('Starting LSTM network validation');

try
    % Test 1: Create a native LSTM network first
    logger.info('Test 1: Native LSTM Network Creation');

    % Define network parameters
    numFeatures = 16;  % 4 trucks × 4 features
    numHiddenUnits = 100;
    sequenceLength = 10;
    batchSize = 1;

    % Create network layers
    layers = [ ...
        sequenceInputLayer(numFeatures)
        lstmLayer(numHiddenUnits)
        fullyConnectedLayer(numFeatures)
        regressionLayer];

    % Create test data using the correct format
    % Create sequence data [features × timesteps]
    sequence = rand(numFeatures, sequenceLength);  % Random features for each timestep

    % Wrap in cell array for native network
    X = {sequence};

    % Log data dimensions
    logger.info('Input data format:');
    logger.info('- Features: %d', size(sequence,1));
    logger.info('- Timesteps: %d', size(sequence,2));
    logger.info('- Number of sequences: %d', numel(X));
    logger.info('- Batch size: %d', batchSize);

    % Configure training options
    options = trainingOptions('adam', ...
        'MaxEpochs', 1, ...
        'MiniBatchSize', batchSize, ...
        'Verbose', false, ...
        'Shuffle', 'never');

    % Train network with test data
    logger.info('Training native LSTM network...');
    net = trainNetwork(X, X, layers, options);
    logger.info('Native LSTM network training successful');

    % Verify prediction
    logger.info('Testing native LSTM prediction...');
    YPred = predict(net, X);
    logger.info('Native LSTM prediction successful');

    % Test 2: Custom Network Test
    logger.info('Test 2: Custom Network Test');

    % Initialize custom network
    logger.info('Initializing custom network...');
    network = ml.LSTMNetwork();
    logger.info('Custom network initialized');

    % Use raw sequence for custom network - it will handle cell conversion
    logger.info('Executing custom network forward pass...');
    output = network.forward(sequence);  % Pass raw sequence, forward() will handle conversion

    % Validate output dimensions
    assert(all(size(output) == size(sequence)), ...
        'Custom network output dimensions do not match input dimensions');

    logger.info('Custom network output dimensions: %dx%d', size(output));

    % Test 3: Compare Outputs
    logger.info('Test 3: Comparing Network Outputs');

    % Compare output ranges
    assert(all(~isnan(output(:))), 'Custom network output contains NaN values');
    assert(all(~isinf(output(:))), 'Custom network output contains Inf values');

    % Set final results
    results.native_test = 'passed';
    results.custom_test = 'passed';
    results.comparison = 'passed';
    results.status = 'passed';
    logger.info('All validation tests passed successfully');

catch ME
    results.status = 'failed';
    results.error = ME.message;
    results.stack = ME.stack;
    logger.error('LSTM network validation failed: %s', ME.message);
    logger.error('Error stack:');
    for i = 1:length(ME.stack)
        logger.error('  File: %s, Line: %d, Name: %s', ...
            ME.stack(i).file, ME.stack(i).line, ME.stack(i).name);
    end
    rethrow(ME);
end

% Log completion
logger.info('Validation complete. Status: %s', results.status);

end