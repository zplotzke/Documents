classdef LSTMNetwork < handle
    % LSTMNETWORK LSTM Neural Network for truck platoon control
    %
    % This class implements a Long Short-Term Memory (LSTM) neural network
    % specifically designed for truck platoon control. It handles:
    % - Network architecture definition
    % - Hyperparameter management
    % - Sequence processing configuration
    % - Training preparation
    % - Forward pass prediction
    %
    % Example:
    %   network = ml.LSTMNetwork();
    %   layers = network.getArchitecture();
    %   network.setHyperparameters(struct('hidden_size', 128));
    %   output = network.forward(input_sequence);
    %
    % Author: zplotzke
    % Last Modified: 2025-02-19 20:24:31 UTC
    % Version: 1.1.2

    properties (Access = private)
        config          % Configuration settings
        input_size     % Size of input features
        hidden_size    % Number of hidden units
        output_size    % Size of output
        num_layers     % Number of LSTM layers
        dropout_rate   % Dropout probability
        sequence_length % Length of input sequences
        initialized    % Flag indicating if network is initialized
        net            % Trained network object
    end

    methods
        function obj = LSTMNetwork()
            % Initialize LSTM network with configuration
            obj.config = config.getConfig();
            obj.loadConfiguration();
            obj.initialized = true;
            obj.net = []; % Will be set after training
        end

        function output = forward(obj, sequence)
            % FORWARD Perform forward pass through the network
            %
            % Parameters:
            %   sequence - Input sequence of shape [features × timesteps]
            %             or [features × timesteps × batch_size]
            %
            % Returns:
            %   output - Network predictions
            %
            % Throws:
            %   - If network is not trained
            %   - If input dimensions are invalid

            if isempty(obj.net)
                error('LSTMNetwork:NotTrained', ...
                    'Network must be trained before making predictions');
            end

            % Validate input dimensions
            [num_features, num_timesteps, batch_size] = obj.validateInputSequence(sequence);

            % Ensure sequence is properly formatted for prediction
            if batch_size == 1
                sequence = reshape(sequence, [num_features, num_timesteps, 1]);
            end

            % Make prediction
            try
                output = predict(obj.net, sequence);
            catch ME
                error('LSTMNetwork:PredictionError', ...
                    'Failed to make prediction: %s', ME.message);
            end
        end

        function layers = getArchitecture(obj)
            % GETARCHITECTURE Get the LSTM network architecture
            %
            % Returns:
            %   layers - Layer graph defining the LSTM network architecture
            %
            % The architecture consists of:
            % 1. Sequence input layer
            % 2. Multiple LSTM layers with dropout
            % 3. Fully connected output layer
            % 4. Regression layer

            if ~obj.initialized
                error('LSTMNetwork:NotInitialized', ...
                    'Network must be initialized before getting architecture');
            end

            layers = layerGraph();

            % Input layer
            layers = addLayers(layers, sequenceInputLayer(obj.input_size, ...
                'Name', 'input'));

            % Add LSTM layers with dropout
            for i = 1:obj.num_layers
                if i == obj.num_layers
                    output_mode = 'last';  % Last layer returns only final timestep
                else
                    output_mode = 'sequence';  % Interior layers return full sequence
                end

                lstm_layer = lstmLayer(obj.hidden_size, ...
                    'Name', sprintf('lstm%d', i), ...
                    'OutputMode', output_mode);

                dropout_layer = dropoutLayer(obj.dropout_rate, ...
                    'Name', sprintf('dropout%d', i));

                layers = addLayers(layers, [lstm_layer; dropout_layer]);
            end

            % Output layers
            fc_layer = fullyConnectedLayer(obj.output_size, 'Name', 'fc');
            reg_layer = regressionLayer('Name', 'output');

            layers = addLayers(layers, [fc_layer; reg_layer]);

            % Connect all layers
            layers = connectLayers(layers, 'input', 'lstm1');
            for i = 1:obj.num_layers-1
                layers = connectLayers(layers, ...
                    sprintf('dropout%d', i), ...
                    sprintf('lstm%d', i+1));
            end
            layers = connectLayers(layers, ...
                sprintf('dropout%d', obj.num_layers), 'fc');
        end

        function setSequenceLength(obj, length)
            % SETSEQUENCELENGTH Set the sequence length for the network
            %
            % Parameters:
            %   length - Number of timesteps in input sequences

            validateattributes(length, {'numeric'}, ...
                {'positive', 'integer', 'scalar'}, ...
                'LSTMNetwork/setSequenceLength', 'length');
            obj.sequence_length = length;
        end

        function length = getSequenceLength(obj)
            % GETSEQUENCELENGTH Get the current sequence length
            length = obj.sequence_length;
        end

        function inputSize = getInputSize(obj)
            % GETINPUTSIZE Get the input feature size
            inputSize = obj.input_size;
        end

        function outputSize = getOutputSize(obj)
            % GETOUTPUTSIZE Get the output size
            outputSize = obj.output_size;
        end

        function setHyperparameters(obj, params)
            % SETHYPERPARAMETERS Update network hyperparameters
            %
            % Parameters:
            %   params - Structure containing hyperparameter values to update
            %
            % Supported fields:
            %   hidden_size  - Number of hidden units in LSTM layers
            %   num_layers   - Number of LSTM layers in the network
            %   dropout_rate - Probability of dropout during training

            if isfield(params, 'hidden_size')
                validateattributes(params.hidden_size, {'numeric'}, ...
                    {'positive', 'integer', 'scalar'}, ...
                    'LSTMNetwork/setHyperparameters', 'hidden_size');
                obj.hidden_size = params.hidden_size;
            end

            if isfield(params, 'num_layers')
                validateattributes(params.num_layers, {'numeric'}, ...
                    {'positive', 'integer', 'scalar'}, ...
                    'LSTMNetwork/setHyperparameters', 'num_layers');
                obj.num_layers = params.num_layers;
            end

            if isfield(params, 'dropout_rate')
                validateattributes(params.dropout_rate, {'numeric'}, ...
                    {'>=', 0, '<', 1, 'scalar'}, ...
                    'LSTMNetwork/setHyperparameters', 'dropout_rate');
                obj.dropout_rate = params.dropout_rate;
            end
        end

        function params = getHyperparameters(obj)
            % GETHYPERPARAMETERS Get current network hyperparameters
            %
            % Returns:
            %   params - Structure containing current hyperparameter values

            params = struct(...
                'input_size', obj.input_size, ...
                'hidden_size', obj.hidden_size, ...
                'output_size', obj.output_size, ...
                'num_layers', obj.num_layers, ...
                'dropout_rate', obj.dropout_rate, ...
                'sequence_length', obj.sequence_length);
        end

        function setTrainedNetwork(obj, trained_net)
            % SETTRAINEDNETWORK Set the trained network object
            %
            % Parameters:
            %   trained_net - Trained MATLAB neural network object

            obj.net = trained_net;
        end
    end

    methods (Access = private)
        function loadConfiguration(obj)
            % Load network configuration from config file
            network_config = obj.config.network;

            % Required parameters
            obj.input_size = network_config.input_size;
            obj.hidden_size = network_config.hidden_size;
            obj.output_size = network_config.output_size;
            obj.dropout_rate = network_config.dropout_rate;
            obj.sequence_length = network_config.sequence_length;

            % Optional parameters with defaults
            obj.num_layers = 2;  % Default to 2 LSTM layers

            % Validate configuration
            obj.validateConfiguration();
        end

        function validateConfiguration(obj)
            % Validate network configuration parameters

            % Check input size
            validateattributes(obj.input_size, {'numeric'}, ...
                {'positive', 'integer', 'scalar'}, ...
                'LSTMNetwork/validateConfiguration', 'input_size');

            % Check hidden size
            validateattributes(obj.hidden_size, {'numeric'}, ...
                {'positive', 'integer', 'scalar'}, ...
                'LSTMNetwork/validateConfiguration', 'hidden_size');

            % Check output size
            validateattributes(obj.output_size, {'numeric'}, ...
                {'positive', 'integer', 'scalar'}, ...
                'LSTMNetwork/validateConfiguration', 'output_size');

            % Check dropout rate
            validateattributes(obj.dropout_rate, {'numeric'}, ...
                {'>=', 0, '<', 1, 'scalar'}, ...
                'LSTMNetwork/validateConfiguration', 'dropout_rate');

            % Check sequence length
            validateattributes(obj.sequence_length, {'numeric'}, ...
                {'positive', 'integer', 'scalar'}, ...
                'LSTMNetwork/validateConfiguration', 'sequence_length');

            % Check number of layers
            validateattributes(obj.num_layers, {'numeric'}, ...
                {'positive', 'integer', 'scalar'}, ...
                'LSTMNetwork/validateConfiguration', 'num_layers');
        end

        function [num_features, num_timesteps, batch_size] = validateInputSequence(obj, sequence)
            % Validate input sequence dimensions

            % Get dimensions
            dims = size(sequence);

            % Check number of dimensions
            if numel(dims) < 2 || numel(dims) > 3
                error('LSTMNetwork:InvalidInputDimensions', ...
                    'Input must be 2D or 3D array (features × timesteps [× batch_size])');
            end

            % Extract dimensions
            num_features = dims(1);
            num_timesteps = dims(2);
            batch_size = 1;
            if numel(dims) == 3
                batch_size = dims(3);
            end

            % Validate feature dimension
            if num_features ~= obj.input_size
                error('LSTMNetwork:InvalidFeatureCount', ...
                    'Input has %d features but network expects %d', ...
                    num_features, obj.input_size);
            end

            % Validate sequence length
            if num_timesteps ~= obj.sequence_length
                error('LSTMNetwork:InvalidSequenceLength', ...
                    'Input has %d timesteps but network expects %d', ...
                    num_timesteps, obj.sequence_length);
            end
        end
    end
end