classdef PlatoonTrainer < handle
    % PLATOONTRAINER Training management for truck platoon LSTM network
    %
    % Author: zplotzke
    % Last Modified: 2025-02-15 05:11:34 UTC
    % Version: 2.0.8

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

                % Initialize components
                obj.network = ml.LSTMNetwork();
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

        function metrics = getTrainingMetrics(obj)
            % GETTRAININGMETRICS Get current training metrics
            metrics = obj.TrainingMetrics;

            % If metrics are empty, return default structure
            if isempty(metrics)
                metrics = struct(...
                    'trainRMSE', [], ...
                    'valRMSE', [], ...
                    'trainTime', [], ...
                    'epochs', [], ...
                    'finalLoss', [], ...
                    'learningCurve', struct(...
                    'trainRMSE', [], ...
                    'valRMSE', [], ...
                    'iterations', [] ...
                    ) ...
                    );
            end
        end

        function stats = getTrainingStats(obj)
            % GETTRAININGSTATS Get detailed training statistics
            stats = struct(...
                'isNetworkTrained', obj.IsNetworkTrained, ...
                'datasetSize', obj.DatasetSize, ...
                'networkConfig', obj.NetworkConfig, ...
                'trainingMetrics', obj.getTrainingMetrics() ...
                );
        end

        function net = getNetwork(obj)
            % GETNETWORK Get trained network
            if ~obj.IsNetworkTrained
                obj.logger.warning('Attempting to get untrained network');
            end
            net = obj.network;
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

            obj.validationData = [];
            obj.preprocessStats = struct(...
                'dataMin', [], ...
                'dataMax', [], ...
                'meanVals', [], ...
                'stdVals', [] ...
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

            % Combine features
            rawFeatures = [obj.trainingData.positions;
                obj.trainingData.velocities;
                obj.trainingData.accelerations;
                obj.trainingData.jerks];

            % Normalize data
            X = obj.normalizeData(rawFeatures);

            % Create target data (next state predictions)
            Y = X(:,2:end);
            X = X(:,1:end-1);

            % Reshape for LSTM [features x sequence_length x samples]
            X = obj.reshapeForLSTM(X);
            Y = obj.reshapeForLSTM(Y);
        end

        function data = normalizeData(obj, data)
            % Normalize data using z-score normalization
            obj.preprocessStats.meanVals = mean(data, 2);
            obj.preprocessStats.stdVals = std(data, 0, 2);

            % Handle constant features
            constFeatures = obj.preprocessStats.stdVals < eps;
            obj.preprocessStats.stdVals(constFeatures) = 1;

            % Normalize
            data = (data - obj.preprocessStats.meanVals) ./ obj.preprocessStats.stdVals;
        end

        function data = reshapeForLSTM(obj, data)
            % Reshape data for LSTM [features x sequence_length x samples]
            [numFeatures, numTimesteps] = size(data);
            numSequences = floor(numTimesteps / obj.config.training.sequence_length);

            if numSequences == 0
                error('PlatoonTrainer:InsufficientData', ...
                    'Not enough timesteps for sequence length');
            end

            % Keep only complete sequences
            useTimesteps = numSequences * obj.config.training.sequence_length;
            data = data(:, 1:useTimesteps);

            % Reshape
            data = reshape(data, numFeatures, ...
                obj.config.training.sequence_length, numSequences);
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
            % Train LSTM network
            obj.trainingStartTime = tic;

            % Set up training parameters
            options = trainingOptions('adam', ...
                'MaxEpochs', obj.config.training.max_epochs, ...
                'MiniBatchSize', obj.config.training.mini_batch_size, ...
                'InitialLearnRate', obj.config.training.learning_rate, ...
                'GradientThreshold', obj.config.training.gradient_threshold, ...
                'ValidationData', {XVal, YVal}, ...
                'ValidationFrequency', 10, ...
                'ValidationPatience', 10, ...
                'Verbose', false);

            % Train network
            [net, info] = trainNetwork(XTrain, YTrain, obj.network.getArchitecture(), options);

            % Calculate metrics
            trainTime = toc(obj.trainingStartTime);
            metrics = obj.calculateTrainingMetrics(net, info, XTrain, YTrain, XVal, YVal, trainTime);
        end

        function metrics = calculateTrainingMetrics(obj, net, info, XTrain, YTrain, XVal, YVal, trainTime)
            % Calculate detailed training metrics
            YPredTrain = predict(net, XTrain);
            YPredVal = predict(net, XVal);

            metrics = struct(...
                'trainRMSE', sqrt(mean((YPredTrain - YTrain).^2, 'all')), ...
                'valRMSE', sqrt(mean((YPredVal - YVal).^2, 'all')), ...
                'trainTime', trainTime, ...
                'epochs', numel(info.TrainingRMSE), ...
                'finalLoss', info.FinalValidationLoss, ...
                'learningCurve', struct(...
                'trainRMSE', info.TrainingRMSE, ...
                'valRMSE', info.ValidationRMSE, ...
                'iterations', 1:numel(info.TrainingRMSE) ...
                ) ...
                );
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

        function validateNetwork(obj, XVal, YVal)
            % Validate network performance
            YPred = predict(obj.network, XVal);
            rmse = sqrt(mean((YPred - YVal).^2, 'all'));

            obj.logger.info('Validation RMSE: %.4f', rmse);
            obj.TrainingMetrics.validationRMSE = rmse;

            % Check for overfitting
            if rmse > 3 * obj.TrainingMetrics.trainRMSE
                obj.logger.warning('Possible overfitting detected');
            end
        end
    end
end