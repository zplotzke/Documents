function trainLSTMNetwork(config, logger)
% TRAINLSTMNETWORK Train LSTM network for truck platoon control prediction
%
% Inputs:
%   config - Configuration structure with simulation and network parameters
%   logger - Logger object with info, error, and debug methods
%
% Author: zplotzke
% Created: 2025-02-08 04:24:35 UTC

try
    logger.info('Training LSTM network...');
    logger.info('Loading simulation data...');

    % Load training data
    data = load(config.simulation.file_names.simulation_data);
    X = data.inputs;  % Features x TimeSteps x Sequences
    Y = data.outputs; % Features x TimeSteps x Sequences

    % Get dimensions
    [numFeatures, numTimeSteps, numSequences] = size(X);

    logger.info('Preparing training data...');
    logger.info('- Number of features: %d', numFeatures);
    logger.info('- Time steps per sequence: %d', numTimeSteps);
    logger.info('- Number of sequences: %d', numSequences);

    % Normalize each feature across all time steps and sequences
    X_flat = reshape(X, numFeatures, []);  % Features x (TimeSteps*Sequences)
    Y_flat = reshape(Y, numFeatures, []);

    params.mean = mean(X_flat, 2);
    params.std = std(X_flat, 0, 2);
    params.std(params.std < eps) = 1;  % Avoid division by zero

    X_norm = (X_flat - params.mean) ./ params.std;
    Y_norm = (Y_flat - params.mean) ./ params.std;

    % Reshape back to 3D
    X_norm = reshape(X_norm, [numFeatures, numTimeSteps, numSequences]);
    Y_norm = reshape(Y_norm, [numFeatures, numTimeSteps, numSequences]);

    % Convert to sequence format for LSTM
    X_sequences = cell(numSequences, 1);
    Y_sequences = cell(numSequences, 1);

    for i = 1:numSequences
        % Get the i-th sequence and transpose to TimeSteps x Features
        % This is the key change - we want each sequence to be TimeSteps x Features
        X_sequences{i} = squeeze(X_norm(:,:,i))';  % TimeSteps x Features
        Y_sequences{i} = squeeze(Y_norm(:,:,i))';  % TimeSteps x Features

        % Debug dimensions of first sequence
        if i == 1
            logger.info('Verifying sequence dimensions...');
            sz = size(X_sequences{i});
            logger.info('- Input sequence size: [%d %d]', sz(1), sz(2));
            assert(sz(2) == numFeatures, ...
                'Wrong feature dimension. Expected %d features, got %d', ...
                numFeatures, sz(2));
        end
    end

    % Split into training and validation sets
    numValidation = max(1, round(numSequences * 0.2));
    validation_idx = randperm(numSequences, numValidation);
    training_idx = setdiff(1:numSequences, validation_idx);

    % Create training and validation sets as cell arrays
    X_train = X_sequences(training_idx);
    Y_train = Y_sequences(training_idx);
    X_val = X_sequences(validation_idx);
    Y_val = Y_sequences(validation_idx);

    % Debug training data format
    logger.info('Checking training data format...');
    logger.info('- X_train is cell array: %d', iscell(X_train));
    logger.info('- First training sequence size: [%d %d]', ...
        size(X_train{1}, 1), size(X_train{1}, 2));
    logger.info('- Number of training sequences: %d', length(X_train));

    % Define LSTM architecture
    layers = [ ...
        sequenceInputLayer(numFeatures, 'Name', 'input')
        lstmLayer(config.lstm.hidden_units, 'OutputMode', 'sequence', 'Name', 'lstm1')
        dropoutLayer(0.2, 'Name', 'drop1')
        lstmLayer(config.lstm.hidden_units/2, 'OutputMode', 'sequence', 'Name', 'lstm2')
        dropoutLayer(0.2, 'Name', 'drop2')
        fullyConnectedLayer(numFeatures, 'Name', 'fc_out')
        regressionLayer('Name', 'output')];

    % Configure training options
    options = trainingOptions('adam', ...
        'MaxEpochs', config.lstm.max_epochs, ...
        'MiniBatchSize', min(config.lstm.mini_batch_size, length(training_idx)), ...
        'InitialLearnRate', config.lstm.initial_learn_rate, ...
        'GradientThreshold', config.lstm.gradient_threshold, ...
        'ValidationData', {X_val, Y_val}, ...
        'ValidationFrequency', 30, ...
        'ValidationPatience', 5, ...
        'Shuffle', 'every-epoch', ...
        'Verbose', true, ...
        'VerboseFrequency', 20, ...
        'Plots', 'none', ...
        'ExecutionEnvironment', 'auto');

    % Train network
    logger.info('Starting network training with validation...');
    logger.info('Training set size: %d sequences', length(X_train));
    logger.info('Validation set size: %d sequences', length(X_val));
    logger.info('Each sequence shape: [%d %d]', numTimeSteps, numFeatures);

    % Train network with sequences
    net = trainNetwork(X_train, Y_train, layers, options);

    % Save trained network and normalization parameters
    logger.info('Saving trained network and parameters...');
    save(config.simulation.file_names.lstm_model, 'net', 'params', '-v7.3');

    logger.info('Network training complete');

catch ME
    logger.error('Training failed: %s', ME.message);
    logger.error('Stack trace: %s', getReport(ME));
    rethrow(ME);
end
end