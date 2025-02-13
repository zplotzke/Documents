classdef PlatoonTrainer < handle
    % PLATOONTRAINER Training management for truck platoon LSTM network
    %
    % Author: zplotzke
    % Last Modified: 2025-02-13 02:00:47 UTC
    % Version: 2.0.6

    properties (SetAccess = private, GetAccess = public)
        IsNetworkTrained  % Boolean indicating if network is trained
        DatasetSize      % Number of collected training samples
        NetworkConfig    % Current network configuration
        TrainingMetrics  % Training performance metrics
    end

    properties (Access = private)
        config              % Configuration settings
        logger             % Logger instance
        network            % LSTM network instance
        trainingData       % Collected training data
        validationData     % Validation dataset
        preprocessStats    % Data preprocessing statistics
        trainingStartTime  % Time when training started
    end

    methods
        function obj = PlatoonTrainer()
            try
                % Initialize logger first
                obj.logger = utils.Logger.getLogger('PlatoonTrainer');

                % Get configuration directly
                obj.config = config.getConfig();

                % Set network dimensions based on truck config
                numTrucks = obj.config.truck.num_trucks;
                numFeatures = 4;  % positions, velocities, accelerations, jerks
                inputSize = numFeatures * numTrucks;
                hiddenSize = obj.config.training.lstm_hidden_units;
                outputSize = inputSize;

                % Initialize network
                obj.network = ml.LSTMNetwork();

                % Initialize data structures
                obj.initializeDataStructures();

                % Initialize public properties
                obj.IsNetworkTrained = false;
                obj.DatasetSize = 0;
                obj.NetworkConfig = obj.config.training;
                obj.TrainingMetrics = struct(...
                    'trainRMSE', [], ...
                    'valRMSE', [], ...
                    'trainTime', [], ...
                    'epochs', [], ...
                    'finalLoss', []);

                obj.logger.info('PlatoonTrainer initialized with LSTM network');

            catch ME
                if ~isempty(obj.logger)
                    obj.logger.error('Initialization failed: %s', ME.message);
                end
                error('PlatoonTrainer:InitializationError', ...
                    'Failed to initialize PlatoonTrainer: %s', ME.message);
            end
        end

        function collectSimulationData(obj, state)
            % COLLECTSIMULATIONDATA Collect state data from simulation
            if obj.IsNetworkTrained
                obj.logger.warning('Collecting data after network training');
            end

            % Add state to training data
            obj.addStateToTrainingData(state);
        end

        function trainNetwork(obj)
            % TRAINNETWORK Train LSTM network on collected data
            if isempty(obj.trainingData.time)
                obj.logger.error('No training data available');
                return;
            end

            try
                % Preprocess data
                [X, Y] = obj.preprocessTrainingData();

                % Split into training and validation sets
                [XTrain, YTrain, XVal, YVal] = obj.splitTrainingData(X, Y);

                % Train network
                obj.logger.info('Starting LSTM network training...');
                [obj.network, metrics] = obj.trainLSTM(XTrain, YTrain, XVal, YVal);
                obj.TrainingMetrics = metrics;

                obj.IsNetworkTrained = true;
                obj.logger.info('Network training completed successfully');

                % Validate network performance
                obj.validateNetwork(XVal, YVal);

            catch ME
                obj.logger.error('Network training failed: %s', ME.message);
                rethrow(ME);
            end
        end

        function net = getNetwork(obj)
            % GETNETWORK Get trained network
            if ~obj.IsNetworkTrained
                obj.logger.warning('Attempting to get untrained network');
            end
            net = obj.network;
        end

        function metrics = getTrainingStats(obj)
            % GETTRAININGMETRICS Get training performance metrics
            metrics = obj.TrainingMetrics;
        end
    end

    methods (Access = private)
        function initializeDataStructures(obj)
            % Initialize data structures for training
            obj.trainingData = struct(...
                'time', [], ...
                'positions', [], ...
                'velocities', [], ...
                'accelerations', [], ...
                'jerks', [] ...
                );
        end

        function addStateToTrainingData(obj, state)
            % Add simulation state to training data
            validateState(obj, state);

            idx = length(obj.trainingData.time) + 1;
            obj.trainingData.time(idx) = state.time;
            obj.trainingData.positions(:,idx) = state.positions;
            obj.trainingData.velocities(:,idx) = state.velocities;
            obj.trainingData.accelerations(:,idx) = state.accelerations;
            obj.trainingData.jerks(:,idx) = state.jerks;

            % Update dataset size
            obj.DatasetSize = idx;
        end

        function [X, Y] = preprocessTrainingData(obj)
            % Preprocess training data for LSTM
            if isempty(obj.trainingData.time)
                error('PlatoonTrainer:EmptyData', 'No training data available');
            end

            % Log data shape before preprocessing
            obj.logger.debug('Raw data shape: positions=%s, velocities=%s', ...
                mat2str(size(obj.trainingData.positions)), ...
                mat2str(size(obj.trainingData.velocities)));

            % Combine features
            rawFeatures = [obj.trainingData.positions;
                obj.trainingData.velocities;
                obj.trainingData.accelerations;
                obj.trainingData.jerks];

            obj.logger.debug('Combined features shape: %s', mat2str(size(rawFeatures)));

            % Ensure we have enough data for sequence
            if size(rawFeatures, 2) < obj.config.training.sequence_length + 1
                error('PlatoonTrainer:InsufficientData', ...
                    'Need at least %d samples for training (got %d)', ...
                    obj.config.training.sequence_length + 1, ...
                    size(rawFeatures, 2));
            end

            % Normalize data
            X = obj.normalizeData(rawFeatures);

            % Create target data (next state predictions)
            Y = X(:,2:end);
            X = X(:,1:end-1);

            obj.logger.debug('Data shapes after splitting: X=%s, Y=%s', ...
                mat2str(size(X)), mat2str(size(Y)));

            % Reshape for LSTM [features x sequence_length x samples]
            X = obj.reshapeForLSTM(X);
            Y = obj.reshapeForLSTM(Y);

            obj.logger.debug('Final shapes: X=%s, Y=%s', ...
                mat2str(size(X)), mat2str(size(Y)));
        end

        function data = normalizeData(obj, data)
            % Normalize data to [-1, 1] range
            obj.logger.debug('Normalizing data of shape: %s', mat2str(size(data)));

            dataMin = min(data, [], 2);
            dataMax = max(data, [], 2);
            range = dataMax - dataMin;

            % Handle constant features
            constFeatures = range < eps;
            if any(constFeatures)
                obj.logger.warning('Found %d constant features', sum(constFeatures));
                range(constFeatures) = 1;
            end

            % Store normalization parameters
            obj.preprocessStats.dataMin = dataMin;
            obj.preprocessStats.dataMax = dataMax;

            % Normalize
            data = 2 * (data - dataMin) ./ range - 1;
        end

        function data = reshapeForLSTM(obj, data)
            % Reshape data for LSTM network [features x sequence_length x samples]
            [numFeatures, numTimesteps] = size(data);

            % Calculate number of complete sequences
            numSequences = floor(numTimesteps / obj.config.training.sequence_length);

            if numSequences == 0
                error('PlatoonTrainer:InsufficientData', ...
                    'Not enough timesteps (%d) for sequence length %d', ...
                    numTimesteps, obj.config.training.sequence_length);
            end

            obj.logger.debug('Reshaping data: features=%d, timesteps=%d, sequences=%d, seq_len=%d', ...
                numFeatures, numTimesteps, numSequences, obj.config.training.sequence_length);

            % Keep only complete sequences
            useTimesteps = numSequences * obj.config.training.sequence_length;
            data = data(:, 1:useTimesteps);

            % Reshape to [features x sequence_length x samples]
            data = reshape(data, numFeatures, obj.config.training.sequence_length, numSequences);
        end

        function [XTrain, YTrain, XVal, YVal] = splitTrainingData(obj, X, Y)
            % Split data into training and validation sets
            numSequences = size(X, 3);
            trainRatio = obj.config.training.train_split_ratio;

            % Randomize split
            rng(obj.config.simulation.random_seed);
            idx = randperm(numSequences);
            trainIdx = idx(1:floor(trainRatio * numSequences));
            valIdx = idx(floor(trainRatio * numSequences) + 1:end);

            % Split data
            XTrain = X(:,:,trainIdx);
            YTrain = Y(:,:,trainIdx);
            XVal = X(:,:,valIdx);
            YVal = Y(:,:,valIdx);
        end

        function [net, metrics] = trainLSTM(obj, XTrain, YTrain, XVal, YVal)
            % Train LSTM network with improved regularization
            options = trainingOptions('adam', ...
                'MaxEpochs', obj.config.training.max_epochs, ...
                'MiniBatchSize', obj.config.training.mini_batch_size, ...
                'InitialLearnRate', obj.config.training.learning_rate, ...
                'GradientThreshold', obj.config.training.gradient_threshold, ...
                'ValidationData', {XVal, YVal}, ...
                'ValidationFrequency', 10, ...
                'ValidationPatience', 10, ...
                'L2Regularization', 0.001, ...
                'LearnRateSchedule', 'piecewise', ...
                'LearnRateDropPeriod', 20, ...
                'LearnRateDropFactor', 0.5, ...
                'Verbose', false, ...
                'Plots', 'training-progress');

            obj.trainingStartTime = tic;
            [net, info] = trainNetwork(XTrain, YTrain, obj.network, options);
            trainTime = toc(obj.trainingStartTime);

            % Calculate final RMSE values
            YPredTrain = predict(net, XTrain);
            trainRMSE = sqrt(mean((YPredTrain - YTrain).^2, 'all'));

            YPredVal = predict(net, XVal);
            valRMSE = sqrt(mean((YPredVal - YVal).^2, 'all'));

            % Store learning curves
            metrics = struct(...
                'trainRMSE', trainRMSE, ...
                'valRMSE', valRMSE, ...
                'trainTime', trainTime, ...
                'epochs', numel(info.TrainingRMSE), ...
                'finalLoss', info.FinalValidationLoss, ...
                'learningCurve', struct(...
                'trainRMSE', info.TrainingRMSE, ...
                'valRMSE', info.ValidationRMSE, ...
                'iterations', 1:numel(info.TrainingRMSE) ...
                ));

            obj.logger.info('Training completed: trainRMSE=%.4f, valRMSE=%.4f, epochs=%d', ...
                metrics.trainRMSE, metrics.valRMSE, metrics.epochs);

            % Log overfitting warning if necessary
            if metrics.valRMSE > 3 * metrics.trainRMSE
                obj.logger.warning('Possible overfitting detected: validation RMSE (%.4f) > 3x training RMSE (%.4f)', ...
                    metrics.valRMSE, metrics.trainRMSE);
            end
        end

        function validateNetwork(obj, XVal, YVal)
            % Validate network performance
            YPred = predict(obj.network, XVal);
            rmse = sqrt(mean((YPred - YVal).^2, 'all'));
            obj.logger.info('Validation RMSE: %.4f', rmse);
            obj.TrainingMetrics.validationRMSE = rmse;
        end

        function validateState(~, state)
            % Validate simulation state structure
            required_fields = {'time', 'positions', 'velocities', ...
                'accelerations', 'jerks'};

            for i = 1:length(required_fields)
                if ~isfield(state, required_fields{i})
                    error('PlatoonTrainer:InvalidState', ...
                        'Missing required field: %s', required_fields{i});
                end
            end
        end
    end
end