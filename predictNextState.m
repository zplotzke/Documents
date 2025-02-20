classdef predictNextState
    % PREDICTNEXTSTATE Predicts the next state for truck platooning system
    %
    % Author: zplotzke
    % Last Modified: 2025-02-19 19:01:56 UTC
    % Version: 1.2.0

    properties (Access = private)
        logger          % Logger instance
        network        % LSTM Network instance
        config         % Configuration
    end

    methods
        function obj = predictNextState()
            % Initialize logger
            obj.logger = utils.Logger.getLogger('PredictNextState');
            obj.logger.info('Logger initialized by zplotzke');

            % Load configuration
            obj.config = config.getConfig();

            % Initialize LSTM network
            obj.network = ml.LSTMNetwork();
        end

        function predictions = predict(obj, currentState)
            % PREDICT Predicts next state based on current state
            %
            % Args:
            %   currentState: Current state matrix [features × timesteps]
            %
            % Returns:
            %   predictions: Predicted next state

            try
                % Validate input
                if nargin < 2
                    obj.logger.error('Missing input: currentState is required');
                    error('predictNextState:InvalidInput', 'currentState is required');
                end

                % Validate input dimensions
                expectedFeatures = obj.network.getInputSize();
                [features, timesteps] = size(currentState);

                if features ~= expectedFeatures
                    obj.logger.error('Invalid input dimensions: expected %d features, got %d', ...
                        expectedFeatures, features);
                    error('predictNextState:InvalidDimensions', ...
                        'Expected %d features, got %d', expectedFeatures, features);
                end

                % Make prediction using LSTM network
                obj.logger.debug('Making prediction for sequence of length %d', timesteps);
                predictions = obj.network.forward(currentState);

                obj.logger.debug('Prediction successful, output shape: %dx%d', ...
                    size(predictions, 1), size(predictions, 2));

            catch ME
                obj.logger.error('Prediction failed: %s', ME.message);
                rethrow(ME);
            end
        end

        function params = getNetworkParameters(obj)
            % Get network parameters
            params = obj.network.getTrainingParameters();
        end
    end
end