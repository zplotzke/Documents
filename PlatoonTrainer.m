classdef PlatoonTrainer < handle
    % PLATOONTRAINER LSTM network training management for truck platoon
    %
    % Manages the collection of training data and LSTM network training for
    % predicting truck platoon behavior:
    % - Collects simulation data
    % - Preprocesses data for training
    % - Trains LSTM network
    % - Validates model performance
    %
    % Author: zplotzke
    % Last Modified: 2025-02-11 15:17:59 UTC
    % Version: 1.0.0

    properties (Access = private)
        config              % Configuration settings
        logger             % Logger instance
        network            % Trained LSTM network
        trainingData       % Collected training data
        validationData     % Validation dataset
        networkTrained     % Flag indicating if network is trained
        trainingMetrics    % Training performance metrics
    end

    methods
        function obj = PlatoonTrainer(config)
            % Constructor
            obj.config = config;
            obj.logger = utils.Logger.getLogger('PlatoonTrainer');
            obj.networkTrained = false;
            obj.initializeDataStructures();

            obj.logger.info('Platoon trainer initialized');
        end

        function collectSimulationData(obj, state)
            % COLLECTSIMULATIONDATA Collect state data from simulation
            if obj.networkTrained
                obj.logger.warning('Collecting data after network training');
            end

            % Add state to training data
            obj.addStateToTrainingData(state);
        end

        function trainNetwork(obj)
            % TRAINNETWORK Train LSTM network on collected data
            if isempty(obj.trainingData)
                obj.logger.error('No training data available');
                return;
            end

            try
                % Preprocess data
                [X, Y] = obj.preprocessTrainingData();

                % Split into training and validation sets
                [XTrain, YTrain, XVal, YVal] = obj.splitTrainingData(X, Y);

                % Configure LSTM network
                obj.configureNetwork();

                % Train network
                obj.logger.info('Starting LSTM network training...');
                [obj.network, obj.trainingMetrics] = obj.trainLSTM(XTrain, YTrain, XVal, YVal);

                obj.networkTrained = true;
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
            if ~obj.networkTrained
                obj.logger.warning('Attempting to get untrained network');
            end
            net = obj.network;
        end

        function metrics = getTrainingMetrics(obj)
            % GETTRAININGMETRICS Get training performance metrics
            metrics = obj.trainingMetrics;
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

            obj.trainingMetrics = struct(...
                'trainRMSE', [], ...
                'valRMSE', [], ...
                'trainTime', [], ...
                'epochs', [], ...
                'finalLoss', [] ...
                );
        end

        function addStateToTrainingData(obj, state)
            % Add simulation state to training data
            obj.trainingData.time(end+1) = state.time;
            obj.trainingData.positions(:,end+1) = state.positions';
            obj.trainingData.velocities(:,end+1) = state.velocities';
            obj.trainingData.accelerations(:,end+1) = state.accelerations';
            obj.trainingData.jerks(:,end+1) = state.jerks';
        end

        function [X, Y] = preprocessTrainingData(obj)
            % Preprocess training data for LSTM

            % Normalize data
            X = obj.normalizeData([
                obj.trainingData.positions;
                obj.trainingData.velocities;
                obj.trainingData.accelerations;
                obj.trainingData.jerks
                ]);

            % Create target data (next state predictions)
            Y = X(:,2:end);
            X = X(:,1:end-1);

            % Reshape for LSTM [features x sequence_length x samples]
            X = obj.reshapeForLSTM(X);
            Y = obj.reshapeForLSTM(Y);
        end

        function data = normalizeData(~, data)
            % Normalize data to [-1, 1] range
            dataMin = min(data, [], 2);
            dataMax = max(data, [], 2);
            data = 2 * (data - dataMin) ./ (dataMax - dataMin) - 1;
        end

        function data = reshapeForLSTM(obj, data)
            % Reshape data for LSTM network
            [numFeatures, numTimesteps] = size(data);
            numSequences = floor(numTimesteps / obj.config.training.sequence_length);

            data = data(:, 1:numSequences * obj.config.training.sequence_length);
            data = reshape(data, numFeatures, obj.config.training.sequence_length, numSequences);
        end

        function [XTrain, YTrain, XVal, YVal] = splitTrainingData(obj, X, Y)
            % Split data into training and validation sets
            numSequences = size(X, 3);
            numTrain = floor(numSequences * (1 - obj.config.training.validation_split));

            XTrain = X(:,:,1:numTrain);
            YTrain = Y(:,:,1:numTrain);
            XVal = X(:,:,numTrain+1:end);
            YVal = Y(:,:,numTrain+1:end);
        end

        function configureNetwork(obj)
            % Configure LSTM network architecture
            layers = [
                sequenceInputLayer(size(obj.trainingData.positions,1) * 4)
                lstmLayer(obj.config.training.lstm_hidden_units, 'OutputMode', 'sequence')
                dropoutLayer(0.2)
                fullyConnectedLayer(size(obj.trainingData.positions,1) * 4)
                regressionLayer
                ];

            obj.network = layers;
        end

        function [net, metrics] = trainLSTM(obj, XTrain, YTrain, XVal, YVal)
            % Train LSTM network
            options = trainingOptions('adam', ...
                'MaxEpochs', obj.config.training.max_epochs, ...
                'MiniBatchSize', obj.config.training.mini_batch_size, ...
                'InitialLearnRate', obj.config.training.learning_rate, ...
                'GradientThreshold', obj.config.training.gradient_threshold, ...
                'ValidationData', {XVal, YVal}, ...
                'ValidationFrequency', 30, ...
                'ValidationPatience', 5, ...
                'Verbose', false, ...
                'Plots', 'training-progress');

            tic;
            [net, info] = trainNetwork(XTrain, YTrain, obj.network, options);
            trainTime = toc;

            % Collect metrics
            metrics = struct(...
                'trainRMSE', sqrt(info.TrainingRMSE), ...
                'valRMSE', sqrt(info.ValidationRMSE), ...
                'trainTime', trainTime, ...
                'epochs', info.NumEpochs, ...
                'finalLoss', info.FinalValidationLoss ...
                );
        end

        function validateNetwork(obj, XVal, YVal)
            % Validate network performance
            YPred = predict(obj.network, XVal);
            rmse = sqrt(mean((YPred - YVal).^2, 'all'));

            obj.logger.info('Validation RMSE: %.4f', rmse);

            % Additional validation metrics could be added here
            obj.trainingMetrics.validationRMSE = rmse;
        end
    end
end