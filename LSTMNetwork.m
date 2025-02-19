classdef LSTMNetwork < handle
    % LSTMNETWORK Long Short-Term Memory Network implementation
    %
    % Author: zplotzke
    % Last Modified: 2025-02-19 17:53:48 UTC
    % Version: 1.3.28

    properties
        InputSize
        HiddenSize
        OutputSize
        Network
        Config
        TrainingOptions
    end

    methods
        function obj = LSTMNetwork()
            % Initialize LSTM network with configuration
            import config.*
            obj.Config = getConfig();

            % Initialize network parameters based on simulation data structure
            numTrucks = obj.Config.truck.num_trucks;  % Default is 4 trucks
            numFeaturesPerTruck = 4;  % [position, velocity, acceleration, jerk]
            obj.InputSize = numTrucks * numFeaturesPerTruck;  % 4 trucks * 4 features = 16
            obj.HiddenSize = 100;  % Default hidden size
            obj.OutputSize = obj.InputSize;  % Same as input for state prediction

            % Create the network structure
            obj.createNetwork();

            % Setup training options
            obj.setupTrainingOptions();

            % Initialize the network with proper training
            obj.initializeNetwork();
        end

        function createNetwork(obj)
            % Create network with standard LSTM layer
            layers = [
                sequenceInputLayer(obj.InputSize, 'Name', 'input')
                lstmLayer(obj.HiddenSize, 'Name', 'lstm')
                fullyConnectedLayer(obj.OutputSize, 'Name', 'fc')
                regressionLayer('Name', 'output')
                ];

            % Create series network
            obj.Network = SeriesNetwork(layers);
        end

        function initializeNetwork(obj)
            % Initialize network with dummy data that matches simulation structure
            dummyFeatures = obj.InputSize;
            dummySequenceLength = 10;
            dummyBatchSize = 1;

            % Create dummy data in [features × timesteps] format
            dummyData = rand(dummyFeatures, dummySequenceLength);
            X = {dummyData};  % Wrap in cell array as MATLAB expects

            % Create simple training options for initialization
            initOptions = trainingOptions('adam', ...
                'MaxEpochs', 1, ...
                'MiniBatchSize', dummyBatchSize, ...
                'Verbose', false, ...
                'Shuffle', 'never');

            try
                % Initialize network with actual training pass
                obj.Network = trainNetwork(X, X, obj.Network.Layers, initOptions);
            catch ME
                error('LSTMNetwork:InitializationError', ...
                    'Failed to initialize network: %s', ME.message);
            end
        end

        function setupTrainingOptions(obj)
            % Convert boolean shuffle to string option
            if obj.Config.trainer.shuffle
                shuffleOption = 'every-epoch';
            else
                shuffleOption = 'never';
            end

            % Setup training options for the network
            obj.TrainingOptions = trainingOptions('adam', ...
                'MaxEpochs', obj.Config.trainer.epochs, ...
                'MiniBatchSize', obj.Config.trainer.batch_size, ...
                'InitialLearnRate', obj.Config.trainer.learning_rate, ...
                'ValidationPatience', obj.Config.trainer.early_stopping_patience, ...
                'ValidationFrequency', 30, ...
                'Shuffle', shuffleOption, ...
                'Verbose', logical(obj.Config.trainer.verbose), ...
                'Plots', 'none');
        end

        function params = getTrainingParameters(obj)
            % Get training parameters from config
            params = struct();
            params.learning_rate = obj.Config.trainer.learning_rate;
            params.batch_size = obj.Config.trainer.batch_size;
            params.epochs = obj.Config.trainer.epochs;
            params.validation_split = obj.Config.trainer.validation_split;
            params.optimizer = obj.Config.trainer.optimizer;
            params.loss_function = obj.Config.trainer.loss_function;
            params.early_stopping_patience = obj.Config.trainer.early_stopping_patience;
            params.min_delta = obj.Config.trainer.min_delta;
            params.shuffle = obj.Config.trainer.shuffle;
        end

        function size = getInputSize(obj)
            size = obj.InputSize;
        end

        function size = getHiddenSize(obj)
            size = obj.HiddenSize;
        end

        function size = getOutputSize(obj)
            size = obj.OutputSize;
        end

        function validateInputDimensions(obj, input)
            % Validate input dimensions for [features × timesteps] format
            if ~iscell(input)
                if size(input, 1) ~= obj.InputSize
                    error('LSTMNetwork:InvalidInput', ...
                        'Input sequence must have feature dimension %d, but got %d', ...
                        obj.InputSize, size(input, 1));
                end
            else
                if size(input{1}, 1) ~= obj.InputSize
                    error('LSTMNetwork:InvalidInput', ...
                        'Input sequence must have feature dimension %d, but got %d', ...
                        obj.InputSize, size(input{1}, 1));
                end
            end
        end

        function output = forward(obj, input)
            % Validate input dimensions
            obj.validateInputDimensions(input);

            % Convert input to cell array format that MATLAB's LSTM expects
            if ~iscell(input)
                % If input is [features × timesteps], wrap in cell
                if size(input, 1) == obj.InputSize
                    X = {input};  % Wrap in cell, keeping [features × timesteps] format
                else
                    % If input is [timesteps × features], transpose then wrap
                    X = {input'};  % Transpose to [features × timesteps] then wrap
                end
            else
                X = input;  % Already in cell format
            end

            try
                % Make prediction using the network
                Y = predict(obj.Network, X);

                % If output is cell array, extract first sequence
                if iscell(Y)
                    output = Y{1};
                else
                    output = Y;
                end
            catch ME
                error('LSTMNetwork:PredictionError', ...
                    'Failed to make prediction: %s', ME.message);
            end
        end

        function output = predict(obj, input)
            % Make prediction using forward pass
            output = forward(obj, input);
        end
    end

    methods(Static)
        function weights = initializeGlorot(fanOut, fanIn)
            % Initialize weights using Glorot initialization
            r = sqrt(6 / (fanIn + fanOut));
            weights = (2 * r) * rand(fanOut, fanIn, 'single') - r;
        end
    end
end