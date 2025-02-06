% calculateandevaluateRMSE.m
% MATLAB Script to Calculate and Evaluate RMSE

% Load Data
load('simulation_data.mat'); % Load the simulation data
inputs = double(inputs); % Initial conditions, not time-series
outputs = double(outputs); % Time-series data

% Flatten the time-series data for feedforward neural network
X_ffn = reshape(outputs, [], size(outputs, 2) * size(outputs, 1))'; % (samples, features)
y_ffn = reshape(outputs, [], size(outputs, 2) * size(outputs, 1))';

% Split data into training and validation sets
idx = randperm(size(X_ffn, 1));
train_idx = idx(1:round(0.8 * length(idx)));
val_idx = idx(round(0.8 * length(idx)) + 1:end);
X_train = X_ffn(train_idx, :);
y_train = y_ffn(train_idx, :);
X_val = X_ffn(val_idx, :);
y_val = y_ffn(val_idx, :);

% Define Feedforward Neural Network
inputSize = size(X_train, 2);
numHiddenUnits = 64;
numOutputs = size(y_train, 2);

layers = [
    featureInputLayer(inputSize)
    fullyConnectedLayer(numHiddenUnits)
    reluLayer
    fullyConnectedLayer(numHiddenUnits)
    reluLayer
    fullyConnectedLayer(numOutputs)
    regressionLayer
    ];

% Training Options
options = trainingOptions('adam', ...
    'MaxEpochs', 50, ...
    'MiniBatchSize', 32, ...
    'Shuffle', 'every-epoch', ...
    'ValidationData', {X_val, y_val}, ...
    'Plots', 'training-progress', ...
    'Verbose', true);

% Train the Model
net = trainNetwork(X_train, y_train, layers, options);

% Save Model
save('feedforward_motion_prediction.mat', 'net');

% Evaluate Model
predictedOutputs = predict(net, X_ffn);
loss = mse(y_ffn - predictedOutputs);
fprintf('Evaluation Loss (MSE): %.4f\n', loss);

% Calculate RMSE
rmse = sqrt(loss);
fprintf('Evaluation Loss (RMSE): %.4f\n', rmse);

% Plot True vs Predicted Outputs
figure;
subplot(2,1,1);
plot(y_ffn(1:1000,1), 'b');
hold on;
plot(predictedOutputs(1:1000,1), 'r');
title('True vs Predicted Outputs (First 1000 Samples)');
legend('True', 'Predicted');

% Calculate and display evaluation metrics
MAE = mean(abs(y_ffn - predictedOutputs), 'all');
fprintf('Mean Absolute Error: %.4f\n', MAE);

RMSE = sqrt(mean((y_ffn - predictedOutputs).^2, 'all'));
fprintf('Root Mean Squared Error: %.4f\n', RMSE);

% Visualize a subset of predictions vs true values
subplot(2,1,2);
plot(y_ffn(1:100,1), 'b');
hold on;
plot(predictedOutputs(1:100,1), 'r');
title('True vs Predicted Outputs (First 100 Samples)');
legend('True', 'Predicted');