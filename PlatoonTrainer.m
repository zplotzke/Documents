classdef PlatoonTrainer < handle
    % PLATOONTRAINER Trainer for truck platoon control system
    %
    % This class handles the training process for the truck platoon
    % control system, including:
    % - Data preparation via simulation
    % - Network training
    % - Model evaluation
    % - Metrics collection
    %
    % Author: zplotzke
    % Last Modified: 2025-02-19 21:02:24 UTC
    % Version: 1.1.8

    properties (Access = private)
        config      % Configuration settings
        network     % LSTM network instance
        metrics     % Training metrics
        logger      % Logger instance
        data        % Collected simulation data
        stats       % Training statistics
        simulator   % Truck platoon simulator instance
    end

    methods
        function obj = PlatoonTrainer()
            % Initialize trainer with configuration
            obj.config = config.getConfig();
            obj.network = ml.LSTMNetwork();
            obj.metrics = struct();
            obj.logger = utils.Logger('PlatoonTrainer');
            obj.logger.info('PlatoonTrainer initialized with LSTM network');
            obj.data = struct('sequences', [], 'targets', []);
            obj.stats = struct(...
                'datasetSize', 0, ...
                'num_sequences', 0, ...
                'sequence_length', 0, ...
                'num_features', 0, ...
                'num_targets', 0, ...
                'num_vehicles', 0, ...
                'total_timesteps', 0, ...
                'training_sequences', 0, ...
                'validation_sequences', 0, ...
                'mean_sequence_spacing', 0, ...
                'std_sequence_spacing', 0, ...
                'data_collection_time', 0);

            % Initialize simulator with correct package reference
            obj.simulator = core.TruckPlatoonSimulation();
        end

        function network = getNetwork(obj)
            % GETNETWORK Get the LSTM network instance
            network = obj.network;
        end

        function stats = getTrainingStats(obj)
            % GETTRAININGSTATS Get statistics about the collected training data
            if ~isempty(obj.data.sequences)
                [num_features, seq_length, num_sequences] = size(obj.data.sequences);
                [num_targets, ~] = size(obj.data.targets);
                num_vehicles = obj.config.truck.num_trucks;

                % Update stats
                obj.stats.datasetSize = num_sequences * seq_length;
                obj.stats.num_sequences = num_sequences;
                obj.stats.sequence_length = seq_length;
                obj.stats.num_features = num_features;
                obj.stats.num_targets = num_targets;
                obj.stats.num_vehicles = num_vehicles;
                obj.stats.total_timesteps = num_sequences + seq_length - 1;

                % Calculate training/validation split
                val_split = obj.config.trainer.validation_split;
                obj.stats.training_sequences = round(num_sequences * (1 - val_split));
                obj.stats.validation_sequences = num_sequences - obj.stats.training_sequences;

                % Update timing stats if time data is available
                if isfield(obj.data, 'collection_times')
                    times = obj.data.collection_times;
                    obj.stats.mean_sequence_spacing = mean(diff(times));
                    obj.stats.std_sequence_spacing = std(diff(times));
                    obj.stats.data_collection_time = times(end) - times(1);
                end
            end

            stats = obj.stats;
        end

        function collectSimulationData(obj, ~)
            % COLLECTSIMULATIONDATA Collect data from truck platoon simulation
            %
            % Runs simulation 10 times with different parameters to collect
            % training data, including both safe and unsafe scenarios

            try
                % Check if we've already collected 10 iterations
                if ~isfield(obj.data, 'iteration_count')
                    obj.data.iteration_count = 0;
                end

                if obj.data.iteration_count >= 10
                    obj.logger.info('Maximum iterations (10) reached, skipping data collection');
                    return;
                end

                % Reset and randomize simulator
                obj.simulator.reset();
                obj.simulator.randomizeParameters();
                obj.simulator.startSimulation('training');

                % Collect simulation data
                positions = [];
                velocities = [];
                accelerations = [];
                times = [];

                while ~obj.simulator.isFinished()
                    state = obj.simulator.step();

                    % Collect state data
                    positions = cat(3, positions, state.positions);
                    velocities = cat(3, velocities, state.velocities);
                    accelerations = cat(3, accelerations, state.accelerations);
                    times = [times; state.time];
                end

                % Format data for sequence processing
                sim_state = struct(...
                    'position', positions, ...
                    'velocity', velocities, ...
                    'acceleration', accelerations, ...
                    'time', times, ...
                    'target_state', obj.computeTargetStates(positions, velocities));

                % Get sequence parameters
                seq_length = obj.network.getSequenceLength();
                if isempty(seq_length)
                    seq_length = 10;  % Default value
                    obj.logger.warning('Using default sequence length: %d', seq_length);
                end

                % Process state into sequences
                [sequences, targets] = obj.processStateIntoSequences(sim_state, seq_length);

                % Store or append data
                if isempty(obj.data.sequences)
                    obj.data.sequences = sequences;
                    obj.data.targets = targets;
                    obj.data.collection_times = times(1);
                else
                    obj.data.sequences = cat(3, obj.data.sequences, sequences);
                    obj.data.targets = cat(2, obj.data.targets, targets);
                    obj.data.collection_times = [obj.data.collection_times; times(1)];
                end

                % Increment iteration count
                obj.data.iteration_count = obj.data.iteration_count + 1;

                obj.logger.info('Collected %d new sequences from simulation (iteration %d/10)', ...
                    size(sequences, 3), obj.data.iteration_count);

            catch ME
                obj.logger.error('Data collection failed: %s', ME.message);
                rethrow(ME);
            end
        end

        function trainNetwork(obj)
            % TRAINNETWORK Train the LSTM network using collected data
            try
                % Get training data
                [XTrain, YTrain, XVal, YVal] = obj.prepareTrainingData();

                % Train LSTM network
                [trained_net, metrics] = obj.trainLSTM(XTrain, YTrain, XVal, YVal);

                % Store trained network
                obj.network.setTrainedNetwork(trained_net);

                % Store metrics
                obj.metrics = metrics;

            catch ME
                obj.logger.error('Network training failed: %s', ME.message);
                rethrow(ME);
            end
        end

        function output = predict(obj, sequence)
            % PREDICT Make predictions using trained network
            %
            % Parameters:
            %   sequence - Input sequence [features × timesteps]
            %
            % Returns:
            %   output - Network predictions

            try
                output = obj.network.forward(sequence);
            catch ME
                obj.logger.error('Prediction failed: %s', ME.message);
                rethrow(ME);
            end
        end

        function metrics = getTrainingMetrics(obj)
            % GETTRAININGMETRICS Get training metrics
            metrics = obj.metrics;
        end

        function saveNetwork(obj, filename)
            % SAVENETWORK Save trained network to file
            %
            % Parameters:
            %   filename - Path to save the network

            try
                network = obj.network;
                metrics = obj.metrics;
                save(filename, 'network', 'metrics', '-v7.3');
                obj.logger.info('Network saved successfully to: %s', filename);
            catch ME
                obj.logger.error('Failed to save network: %s', ME.message);
                rethrow(ME);
            end
        end

        function loadNetwork(obj, filename)
            % LOADNETWORK Load trained network from file
            %
            % Parameters:
            %   filename - Path to the saved network

            try
                data = load(filename);
                obj.network.setTrainedNetwork(data.network);
                obj.metrics = data.metrics;
                obj.logger.info('Network loaded successfully from: %s', filename);
            catch ME
                obj.logger.error('Failed to load network: %s', ME.message);
                rethrow(ME);
            end
        end
    end

    methods (Access = private)
        function target_states = computeTargetStates(obj, positions, velocities)
            % COMPUTETARGETSTATES Compute target states from simulation data
            %
            % Computes desired future states based on current positions and velocities

            [~, num_vehicles, num_timesteps] = size(positions);
            target_dim = 6;  % [x,y,heading,v_x,v_y,omega]
            target_states = zeros(target_dim, num_timesteps);

            % For now, just use lead vehicle's state as target
            % In practice, this would involve more sophisticated prediction
            lead_idx = 1;
            for t = 1:num_timesteps
                target_states(1:3,t) = positions(:,lead_idx,t);
                target_states(4:6,t) = velocities(:,lead_idx,t);
            end
        end

        function [sequences, targets] = processStateIntoSequences(obj, state, seq_length)
            % Process simulation state into training sequences

            % Extract state components
            position = state.position;      % [x,y,heading] × vehicles × timesteps
            velocity = state.velocity;      % [v_x,v_y,omega] × vehicles × timesteps
            acceleration = state.acceleration; % [a_x,a_y,alpha] × vehicles × timesteps
            time = state.time;             % time vector
            target_state = state.target_state; % target states

            % Get dimensions
            [~, num_vehicles, num_timesteps] = size(position);

            % Validate data dimensions
            if num_timesteps < seq_length
                throw(MException('PlatoonTrainer:InsufficientData', ...
                    'Not enough timesteps for sequence creation'));
            end

            % Calculate number of sequences
            num_sequences = num_timesteps - seq_length + 1;

            % Combine state information
            % Features: [position; velocity; acceleration] for each vehicle
            num_features_per_vehicle = 9;  % 3 pos + 3 vel + 3 acc
            num_features = num_features_per_vehicle * num_vehicles;

            % Initialize output arrays
            sequences = zeros(num_features, seq_length, num_sequences);
            targets = zeros(size(target_state, 1), num_sequences);

            % Create sequences
            for i = 1:num_sequences
                seq_idx = i:i+seq_length-1;

                % Build feature vector for each timestep
                for t = 1:seq_length
                    idx = seq_idx(t);
                    feature_idx = 1;

                    for v = 1:num_vehicles
                        % Add position data
                        sequences(feature_idx:feature_idx+2, t, i) = position(:,v,idx);
                        feature_idx = feature_idx + 3;

                        % Add velocity data
                        sequences(feature_idx:feature_idx+2, t, i) = velocity(:,v,idx);
                        feature_idx = feature_idx + 3;

                        % Add acceleration data
                        sequences(feature_idx:feature_idx+2, t, i) = acceleration(:,v,idx);
                        feature_idx = feature_idx + 3;
                    end
                end

                % Store target state
                targets(:,i) = target_state(:,i+seq_length-1);
            end
        end

        function [XTrain, YTrain, XVal, YVal] = prepareTrainingData(obj)
            % PREPARETRAININGDATA Prepare data for network training
            %
            % Returns:
            %   XTrain - Training input sequences
            %   YTrain - Training target values
            %   XVal   - Validation input sequences
            %   YVal   - Validation target values

            % Load and preprocess data
            data = struct('X', obj.data.sequences, 'Y', obj.data.targets);

            % Split into training and validation sets
            val_split = obj.config.trainer.validation_split;
            num_sequences = size(data.X, 3);
            num_val = round(num_sequences * val_split);

            % Randomly shuffle data
            if obj.config.trainer.shuffle
                idx = randperm(num_sequences);
                data.X = data.X(:,:,idx);
                data.Y = data.Y(:,idx);
            end

            % Split data
            XTrain = data.X(:,:,1:end-num_val);
            YTrain = data.Y(:,1:end-num_val);
            XVal = data.X(:,:,end-num_val+1:end);
            YVal = data.Y(:,end-num_val+1:end);

            obj.logger.info('Training data prepared: %d training sequences, %d validation sequences', ...
                size(XTrain,3), size(XVal,3));
        end

        function [trained_net, metrics] = trainLSTM(obj, XTrain, YTrain, XVal, YVal)
            % TRAINLSTM Train the LSTM network
            %
            % Parameters:
            %   XTrain - Training input sequences
            %   YTrain - Training target values
            %   XVal   - Validation input sequences
            %   YVal   - Validation target values
            %
            % Returns:
            %   trained_net - Trained network
            %   metrics     - Training metrics

            % Get network architecture
            layers = obj.network.getArchitecture();

            % Configure training options
            options = trainingOptions('adam', ...
                'MaxEpochs', obj.config.trainer.epochs, ...
                'MiniBatchSize', obj.config.trainer.batch_size, ...
                'InitialLearnRate', obj.config.trainer.learning_rate, ...
                'GradientThreshold', 1, ...
                'LearnRateSchedule', 'piecewise', ...
                'LearnRateDropPeriod', 20, ...
                'LearnRateDropFactor', 0.1, ...
                'ValidationData', {XVal, YVal}, ...
                'ValidationFrequency', 10, ...
                'ValidationPatience', obj.config.trainer.early_stopping_patience, ...
                'Shuffle', 'every-epoch', ...
                'Verbose', obj.config.trainer.verbose, ...
                'Plots', 'none');

            % Train network
            try
                obj.logger.info('Starting LSTM network training...');
                [net, info] = trainNetwork(XTrain, YTrain, layers, options);

                % Collect metrics
                metrics = struct(...
                    'training_loss', info.TrainingLoss, ...
                    'validation_loss', info.ValidationLoss, ...
                    'training_rmse', info.TrainingRMSE, ...
                    'validation_rmse', info.ValidationRMSE, ...
                    'final_validation_loss', info.ValidationLoss(end), ...
                    'best_validation_epoch', info.BestEpoch, ...
                    'training_time', info.TrainingTime, ...
                    'final_learning_rate', info.FinalLearnRate);

                trained_net = net;
                obj.logger.info('LSTM network training completed successfully in %.2f seconds', ...
                    info.TrainingTime);

            catch ME
                obj.logger.error('LSTM training failed: %s', ME.message);
                rethrow(ME);
            end
        end
    end
end