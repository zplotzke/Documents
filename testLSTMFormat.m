function results = testLSTMFormat()
% TESTLSTMFORMAT Test proper LSTM input formatting
%
% Author: zplotzke
% Last Modified: 2025-02-19 17:44:51 UTC
% Version: 1.0.2

% Initialize logger
logger = utils.Logger.getLogger('testLSTMFormat');
logger.info('Starting LSTM format test');

try
    % Create minimal network
    numFeatures = 2;  % Use small numbers for clarity
    layers = [ ...
        sequenceInputLayer(numFeatures)
        lstmLayer(3)
        fullyConnectedLayer(numFeatures)
        regressionLayer];

    % Create simple test data
    sequenceLength = 5;
    numObservations = 1;

    % Create data as a cell array with transposed sequence
    X = cell(numObservations, 1);

    % Create sequence data [features × timesteps] instead of [timesteps × features]
    sequence = zeros(numFeatures, sequenceLength);
    for i = 1:sequenceLength
        sequence(:,i) = [i; i*10];  % Note: using column vector here
    end
    X{1} = sequence;

    % Log the data for verification
    logger.info('Test data (transposed format):');
    logger.info('Features: %d, Timesteps: %d', size(sequence,1), size(sequence,2));
    for i = 1:sequenceLength
        logger.info('Timestep %d: [%.1f, %.1f]', i, sequence(1,i), sequence(2,i));
    end

    % Log dimensions
    logger.info('Sequence dimensions: %dx%d [features × timesteps]', size(sequence));
    logger.info('Number of sequences: %d', numel(X));

    % Try to train
    options = trainingOptions('adam', ...
        'MaxEpochs',1, ...
        'Verbose',false);

    net = trainNetwork(X, X, layers, options);
    logger.info('Training successful');

    % Try prediction
    Y = predict(net, X);
    logger.info('Prediction successful');
    if iscell(Y)
        logger.info('Output sequence dimensions: %dx%d', size(Y{1}));
    else
        logger.info('Output dimensions: %dx%dx%d', size(Y,1), size(Y,2), size(Y,3));
    end

    results.status = 'passed';

catch ME
    logger.error('Test failed: %s', ME.message);
    results.status = 'failed';
    results.error = ME.message;

    % Add more debug info
    logger.error('Error stack:');
    for i = 1:length(ME.stack)
        logger.error('  File: %s, Line: %d, Name: %s', ...
            ME.stack(i).file, ME.stack(i).line, ME.stack(i).name);
    end

    % Add dimension info even if we fail
    if exist('sequence', 'var')
        logger.error('Failed sequence dimensions: %dx%d', size(sequence));
    end
    rethrow(ME);
end

end