classdef LSTMNetwork < handle
    % LSTMNetwork Long Short-Term Memory Network implementation
    %
    % Author: zplotzke
    % Last Modified: 2025-02-12 17:38:14 UTC
    % Version: 1.0.6

    properties
        InputSize
        HiddenSize
        OutputSize
        IsTrained
        config
        optimizer
        gradients

        % Network parameters
        Wi  % Input gate weights for input
        Ui  % Input gate weights for hidden state
        bi  % Input gate bias

        Wf  % Forget gate weights for input
        Uf  % Forget gate weights for hidden state
        bf  % Forget gate bias

        Wc  % Cell state weights for input
        Uc  % Cell state weights for hidden state
        bc  % Cell state bias

        Wo  % Output gate weights for input
        Uo  % Output gate weights for hidden state
        bo  % Output gate bias

        Wy  % Output layer weights
        by  % Output layer bias

        % Logger instance
        logger

        % Training parameters
        bestLoss = Inf
        patienceCount = 0
        bestWeights
    end

    methods
        function obj = LSTMNetwork()
            try
                % Initialize logger first
                obj.logger = utils.Logger.getLogger('LSTMNetwork');

                % Load configuration
                obj.config = config.getConfig();

                % Set network dimensions based on truck config
                numTrucks = obj.config.truck.num_trucks;
                numFeatures = 4;  % positions, velocities, accelerations, jerks
                obj.InputSize = numFeatures * numTrucks;
                obj.HiddenSize = obj.config.training.lstm_hidden_units;
                obj.OutputSize = obj.InputSize;

                % Initialize parameters
                obj = initializeParameters(obj);

                % Initialize optimizer with global config values
                obj.optimizer = obj.initializeOptimizer();

                obj.logger.info('LSTM Network initialized with input size %d, hidden size %d', ...
                    obj.InputSize, obj.HiddenSize);

            catch ME
                if ~isempty(obj.logger)
                    obj.logger.error('Initialization failed: %s', ME.message);
                end
                rethrow(ME);
            end
        end

        function [output, state] = forward(obj, input, state)
            try
                batchSize = size(input, 2);

                % Initialize or get state variables
                if isempty(state)
                    % Initialize new state
                    h = zeros(obj.HiddenSize, batchSize);
                    c = zeros(obj.HiddenSize, batchSize);
                else
                    % Get existing state
                    if ~isstruct(state)
                        state = struct('h', zeros(obj.HiddenSize, batchSize), ...
                            'c', zeros(obj.HiddenSize, batchSize));
                    end
                    if ~isfield(state, 'h') || ~isfield(state, 'c')
                        state.h = zeros(obj.HiddenSize, batchSize);
                        state.c = zeros(obj.HiddenSize, batchSize);
                    end
                    h = state.h;
                    c = state.c;
                end

                % Store previous states for backprop
                h_prev = h;
                c_prev = c;

                % Input gate
                i = obj.sigmoid(obj.Wi * input + obj.Ui * h + obj.bi);

                % Forget gate
                f = obj.sigmoid(obj.Wf * input + obj.Uf * h + obj.bf);

                % Cell candidate
                c_tilde = obj.tanh(obj.Wc * input + obj.Uc * h + obj.bc);

                % Output gate
                o = obj.sigmoid(obj.Wo * input + obj.Uo * h + obj.bo);

                % Cell state update
                c = f .* c + i .* c_tilde;

                % Hidden state update
                h = o .* obj.tanh(c);

                % Output layer
                output = obj.Wy * h + obj.by;

                % Update state and cache
                state.h = h;
                state.c = c;
                state.cache = struct(...
                    'x', input, ...
                    'h_prev', h_prev, ...
                    'c_prev', c_prev, ...
                    'i', i, ...
                    'f', f, ...
                    'c', c, ...
                    'c_tilde', c_tilde, ...
                    'o', o, ...
                    'h', h, ...
                    'output', output);

            catch ME
                obj.logger.error('Forward pass failed: %s', ME.message);
                rethrow(ME);
            end
        end

        function [loss, gradients] = backward(obj, input, target, ~, cache)
            try
                % Initialize gradients
                obj.initializeGradients();

                % Get batch size
                batchSize = size(input, 2);

                % Compute loss
                loss = obj.computeLoss(cache.output, target);

                % Initialize gradient accumulators
                dh = zeros(obj.HiddenSize, batchSize);
                dc = zeros(obj.HiddenSize, batchSize);

                % Reshape output and target if needed
                if size(cache.output, 2) ~= batchSize
                    cache.output = reshape(cache.output, [], batchSize);
                end
                if size(target, 2) ~= batchSize
                    target = reshape(target, [], batchSize);
                end

                % Backprop through output layer
                dy = cache.output - target;
                obj.gradients.Wy = dy * cache.h';
                obj.gradients.by = sum(dy, 2);
                dh = obj.Wy' * dy;

                % Backprop through LSTM cell
                [~, ~] = obj.backpropCell(dh, dc, cache, 1);

                % Apply gradient clipping
                obj.clipGradients();

                gradients = obj.gradients;

            catch ME
                obj.logger.error('Backward pass failed: %s', ME.message);
                rethrow(ME);
            end
        end

        function train(obj, X, Y, validationData)
            try
                numEpochs = obj.config.training.max_epochs;
                batchSize = obj.config.training.mini_batch_size;
                patience = 10;  % Number of epochs to wait for improvement
                minDelta = 1e-4;  % Minimum improvement required

                % Store initial weights
                obj.bestWeights = obj.getWeights();

                for epoch = 1:numEpochs
                    % Shuffle training data
                    idx = randperm(size(X, 2));
                    X = X(:, idx);
                    Y = Y(:, idx);

                    % Mini-batch training
                    numBatches = floor(size(X, 2) / batchSize);
                    epochLoss = 0;

                    for batch = 1:numBatches
                        batchIdx = (batch-1)*batchSize + 1 : batch*batchSize;
                        Xbatch = X(:, batchIdx);
                        Ybatch = Y(:, batchIdx);

                        % Forward and backward passes
                        state = [];
                        [~, newState] = obj.forward(Xbatch, state);
                        [batchLoss, gradients] = obj.backward(Xbatch, Ybatch, newState, newState.cache);

                        % Update parameters
                        obj.updateParameters(gradients);

                        epochLoss = epochLoss + batchLoss;
                    end

                    epochLoss = epochLoss / numBatches;

                    % Validation
                    if ~isempty(validationData)
                        valLoss = obj.validate(validationData.X, validationData.Y);

                        % Early stopping check
                        if valLoss < (obj.bestLoss - minDelta)
                            obj.bestLoss = valLoss;
                            obj.bestWeights = obj.getWeights();
                            obj.patienceCount = 0;
                        else
                            obj.patienceCount = obj.patienceCount + 1;
                            if obj.patienceCount >= patience
                                obj.logger.info(['Early stopping triggered at epoch ' num2str(epoch)]);
                                obj.setWeights(obj.bestWeights);  % Restore best weights
                                break;
                            end
                        end

                        obj.logger.info('Epoch %d/%d - Training Loss: %.4f, Validation Loss: %.4f', ...
                            epoch, numEpochs, epochLoss, valLoss);
                    else
                        obj.logger.info('Epoch %d/%d - Training Loss: %.4f', ...
                            epoch, numEpochs, epochLoss);
                    end
                end

                obj.IsTrained = true;
                obj.logger.info('Training completed successfully');

            catch ME
                obj.logger.error('Training failed: %s', ME.message);
                rethrow(ME);
            end
        end

        function predictions = predict(obj, X)
            if ~obj.IsTrained
                obj.logger.warning('Attempting prediction with untrained network');
            end

            try
                state = [];
                [predictions, ~] = obj.forward(X, state);

            catch ME
                obj.logger.error('Prediction failed: %s', ME.message);
                rethrow(ME);
            end
        end

        function disp(obj)
            fprintf('  LSTM Network:\n');
            fprintf('    Input Size: %d\n', obj.InputSize);
            fprintf('    Hidden Size: %d\n', obj.HiddenSize);
            fprintf('    Output Size: %d\n', obj.OutputSize);
            fprintf('    Trained: %s\n', mat2str(obj.IsTrained));
        end

        function display(obj)
            fprintf('\n');
            disp(obj);
        end
    end

    methods (Access = private)
        function obj = initializeParameters(obj)
            % Initialize input gate parameters
            obj.Wi = randn(obj.HiddenSize, obj.InputSize) * sqrt(2/(obj.InputSize + obj.HiddenSize));
            obj.Ui = randn(obj.HiddenSize, obj.HiddenSize) * sqrt(2/(obj.HiddenSize + obj.HiddenSize));
            obj.bi = zeros(obj.HiddenSize, 1);

            % Initialize forget gate parameters
            obj.Wf = randn(obj.HiddenSize, obj.InputSize) * sqrt(2/(obj.InputSize + obj.HiddenSize));
            obj.Uf = randn(obj.HiddenSize, obj.HiddenSize) * sqrt(2/(obj.HiddenSize + obj.HiddenSize));
            obj.bf = zeros(obj.HiddenSize, 1);

            % Initialize cell state parameters
            obj.Wc = randn(obj.HiddenSize, obj.InputSize) * sqrt(2/(obj.InputSize + obj.HiddenSize));
            obj.Uc = randn(obj.HiddenSize, obj.HiddenSize) * sqrt(2/(obj.HiddenSize + obj.HiddenSize));
            obj.bc = zeros(obj.HiddenSize, 1);

            % Initialize output gate parameters
            obj.Wo = randn(obj.HiddenSize, obj.InputSize) * sqrt(2/(obj.InputSize + obj.HiddenSize));
            obj.Uo = randn(obj.HiddenSize, obj.HiddenSize) * sqrt(2/(obj.HiddenSize + obj.HiddenSize));
            obj.bo = zeros(obj.HiddenSize, 1);

            % Initialize output layer parameters
            obj.Wy = randn(obj.OutputSize, obj.HiddenSize) * sqrt(2/(obj.HiddenSize + obj.OutputSize));
            obj.by = zeros(obj.OutputSize, 1);
        end

        function optimizer = initializeOptimizer(obj)
            optimizer = struct();
            optimizer.learning_rate = obj.config.training.learning_rate;
            optimizer.beta1 = 0.9;
            optimizer.beta2 = 0.999;
            optimizer.epsilon = 1e-8;
            optimizer.m = struct();
            optimizer.v = struct();
            optimizer.t = 0;

            params = {'Wi', 'Wf', 'Wc', 'Wo', 'Ui', 'Uf', 'Uc', 'Uo', ...
                'bi', 'bf', 'bc', 'bo', 'Wy', 'by'};

            for i = 1:length(params)
                param = params{i};
                optimizer.m.(param) = zeros(size(obj.(param)));
                optimizer.v.(param) = zeros(size(obj.(param)));
            end
        end

        function initializeGradients(obj)
            obj.gradients = struct();
            params = {'Wi', 'Wf', 'Wc', 'Wo', 'Ui', 'Uf', 'Uc', 'Uo', ...
                'bi', 'bf', 'bc', 'bo', 'Wy', 'by'};

            for i = 1:length(params)
                param = params{i};
                obj.gradients.(param) = zeros(size(obj.(param)));
            end
        end

        function loss = computeLoss(~, output, target)
            loss = mean((output - target).^2, 'all');
        end

        function [dh, dc] = backpropCell(obj, dh, dc, cache, ~)
            try
                % Get batch size
                batchSize = size(dh, 2);

                % Verify dimensions
                assert(all(size(cache.h) == [obj.HiddenSize, batchSize]), ...
                    'Hidden state dimension mismatch');
                assert(all(size(cache.c) == [obj.HiddenSize, batchSize]), ...
                    'Cell state dimension mismatch');

                % Gradients through tanh
                do = dh .* obj.tanh(cache.c);
                dc = dc + dh .* cache.o .* (1 - obj.tanh(cache.c).^2);

                % Gradients through gates
                di = dc .* cache.c_tilde;
                df = dc .* cache.c_prev;
                dc_tilde = dc .* cache.i;

                % Update gradients
                obj.gradients.Wo = obj.gradients.Wo + do * cache.x';
                obj.gradients.Uo = obj.gradients.Uo + do * cache.h_prev';
                obj.gradients.bo = obj.gradients.bo + sum(do, 2);

                obj.gradients.Wi = obj.gradients.Wi + di * cache.x';
                obj.gradients.Ui = obj.gradients.Ui + di * cache.h_prev';
                obj.gradients.bi = obj.gradients.bi + sum(di, 2);

                obj.gradients.Wf = obj.gradients.Wf + df * cache.x';
                obj.gradients.Uf = obj.gradients.Uf + df * cache.h_prev';
                obj.gradients.bf = obj.gradients.bf + sum(df, 2);

                obj.gradients.Wc = obj.gradients.Wc + dc_tilde * cache.x';
                obj.gradients.Uc = obj.gradients.Uc + dc_tilde * cache.h_prev';
                obj.gradients.bc = obj.gradients.bc + sum(dc_tilde, 2);

            catch ME
                obj.logger.error('Backprop cell failed: %s', ME.message);
                rethrow(ME);
            end
        end

        function weights = getWeights(obj)
            % Get current network weights
            weights = struct();
            params = {'Wi', 'Ui', 'bi', 'Wf', 'Uf', 'bf', 'Wc', 'Uc', 'bc', ...
                'Wo', 'Uo', 'bo', 'Wy', 'by'};
            for i = 1:length(params)
                param = params{i};
                weights.(param) = obj.(param);
            end
        end

        function setWeights(obj, weights)
            % Set network weights
            params = fieldnames(weights);
            for i = 1:length(params)
                param = params{i};
                obj.(param) = weights.(param);
            end
        end

        function clipGradients(obj)
            % Apply gradient clipping
            threshold = obj.config.training.gradient_threshold;

            params = fieldnames(obj.gradients);
            for i = 1:length(params)
                param = params{i};
                grad = obj.gradients.(param);
                norm_grad = sqrt(sum(grad.^2, 'all'));

                if norm_grad > threshold
                    obj.gradients.(param) = grad * (threshold / norm_grad);
                end
            end
        end

        function updateParameters(obj, gradients)
            % Update parameters using Adam optimizer
            obj.optimizer.t = obj.optimizer.t + 1;

            % Update for each parameter
            params = fieldnames(gradients);
            for i = 1:length(params)
                param = params{i};
                grad = gradients.(param);

                % Update biased first moment estimate
                obj.optimizer.m.(param) = obj.optimizer.beta1 * obj.optimizer.m.(param) + ...
                    (1 - obj.optimizer.beta1) * grad;

                % Update biased second raw moment estimate
                obj.optimizer.v.(param) = obj.optimizer.beta2 * obj.optimizer.v.(param) + ...
                    (1 - obj.optimizer.beta2) * grad.^2;

                % Compute bias-corrected first moment estimate
                m_hat = obj.optimizer.m.(param) / (1 - obj.optimizer.beta1^obj.optimizer.t);

                % Compute bias-corrected second raw moment estimate
                v_hat = obj.optimizer.v.(param) / (1 - obj.optimizer.beta2^obj.optimizer.t);

                % Update parameters
                obj.(param) = obj.(param) - obj.optimizer.learning_rate * ...
                    m_hat ./ (sqrt(v_hat) + obj.optimizer.epsilon);
            end
        end

        function valLoss = validate(obj, X, Y)
            % Perform validation and compute validation loss
            try
                state = [];
                [output, ~] = obj.forward(X, state);
                valLoss = obj.computeLoss(output, Y);
            catch ME
                obj.logger.error('Validation failed: %s', ME.message);
                rethrow(ME);
            end
        end

        function y = sigmoid(~, x)
            % Sigmoid activation function
            y = 1 ./ (1 + exp(-x));
        end

        function y = tanh(~, x)
            % Hyperbolic tangent activation function
            y = tanh(x);  % Using MATLAB's built-in tanh
        end
    end
end