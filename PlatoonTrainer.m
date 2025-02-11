classdef PlatoonTrainer < handle
    % PLATOONTRAINER Handles LSTM training and prediction for truck platoon
    %
    % Author: zplotzke
    % Last Modified: 2025-02-11 14:40:59 UTC

    properties (Access = private)
        config
        logger
        network
        normParams
        trainingData
    end

    methods
        function obj = PlatoonTrainer(config, logger)
            obj.config = config;
            obj.logger = logger;
            obj.trainingData = struct('inputs', [], 'outputs', []);
        end

        function collectSimulationData(obj, state)
            % Record state from each simulation run
            currentData = [
                state.positions;
                state.velocities;
                state.accelerations;
                state.jerks
                ];

            if isempty(obj.trainingData.inputs)
                obj.trainingData.inputs = currentData;
            else
                obj.trainingData.inputs(:,:,end+1) = currentData;
            end
        end

        function trainNetwork(obj)
            % Move code from trainLSTMNetwork.m here
            obj.logger.info('Training LSTM network...');

            % Normalize data
            [X_norm, Y_norm] = obj.normalizeData(obj.trainingData.inputs);

            % Configure and train network
            layers = obj.configureLSTMLayers();
            options = obj.configureLSTMOptions();

            obj.network = trainNetwork(X_norm, Y_norm, layers, options);
        end

        function predictions = predict(obj, state)
            % Make predictions using trained network
            currentState = [
                state.positions;
                state.velocities;
                state.accelerations;
                state.jerks
                ];

            % Normalize input
            stateNorm = (currentState - obj.normParams.mean) ./ obj.normParams.std;

            % Get prediction
            predNorm = predict(obj.network, stateNorm);

            % Denormalize output
            predictions = predNorm .* obj.normParams.std + obj.normParams.mean;
        end
    end
end