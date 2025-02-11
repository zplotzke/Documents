function [predictions] = predictNextState(network, currentState)
% PREDICTNEXTSTATE Predict next state of truck platoon using LSTM network
%
% Inputs:
%   network - Trained LSTM network
%   currentState - Current state of the platoon containing:
%     - positions
%     - velocities
%     - accelerations
%     - jerks
%
% Outputs:
%   predictions - Struct containing predicted:
%     - positions
%     - velocities
%     - accelerations
%     - jerks
%
% Author: zplotzke
% Last Modified: 2025-02-11 15:22:53 UTC
% Version: 1.0.0

% Get logger instance
logger = utils.Logger.getLogger('PredictNextState');

try
    % Validate inputs
    validateInputs(network, currentState);

    % Prepare input data
    X = prepareInputData(currentState);

    % Make prediction
    Y = predict(network, X);

    % Convert prediction back to state format
    predictions = convertPredictions(Y);

    % Apply physical constraints
    predictions = applyConstraints(predictions, currentState);

catch ME
    logger.error('Prediction failed: %s', ME.message);
    % Return current state as prediction if error occurs
    predictions = currentState;
    rethrow(ME);
end
end

function validateInputs(network, state)
% Validate input parameters
if isempty(network)
    error('predictNextState:EmptyNetwork', 'Network cannot be empty');
end

requiredFields = {'positions', 'velocities', 'accelerations', 'jerks'};
for i = 1:length(requiredFields)
    if ~isfield(state, requiredFields{i})
        error('predictNextState:MissingField', ...
            'State must contain field: %s', requiredFields{i});
    end
end

% Validate dimensions
fieldLengths = [
    length(state.positions)
    length(state.velocities)
    length(state.accelerations)
    length(state.jerks)
    ];

if any(fieldLengths ~= fieldLengths(1))
    error('predictNextState:InconsistentDimensions', ...
        'All state fields must have the same length');
end
end

function X = prepareInputData(state)
% Prepare input data for LSTM network
% Combine state variables into input matrix
X = [
    state.positions';
    state.velocities';
    state.accelerations';
    state.jerks'
    ];

% Normalize data
X = normalizeData(X);

% Reshape for LSTM [features x sequence_length x samples]
X = reshape(X, size(X,1), 1, 1);
end

function data = normalizeData(data)
% Normalize data to [-1, 1] range
% Note: These scaling factors should match those used in training
positionScale = 1000;  % Typical position range in meters
velocityScale = 30;    % Typical velocity range in m/s
accelerationScale = 5; % Typical acceleration range in m/s^2
jerkScale = 2;        % Typical jerk range in m/s^3

scales = [
    positionScale * ones(1, size(data,2)/4)
    velocityScale * ones(1, size(data,2)/4)
    accelerationScale * ones(1, size(data,2)/4)
    jerkScale * ones(1, size(data,2)/4)
    ];

data = data ./ scales;
end

function predictions = convertPredictions(Y)
% Convert network output back to state format
% Denormalize predictions
Y = denormalizeData(Y);

% Extract individual state components
numVars = size(Y,1)/4;
predictions = struct(...
    'positions', Y(1:numVars), ...
    'velocities', Y(numVars+1:2*numVars), ...
    'accelerations', Y(2*numVars+1:3*numVars), ...
    'jerks', Y(3*numVars+1:end) ...
    );
end

function data = denormalizeData(data)
% Denormalize data from [-1, 1] range
% Note: These scaling factors should match those used in normalizeData
positionScale = 1000;
velocityScale = 30;
accelerationScale = 5;
jerkScale = 2;

scales = [
    positionScale * ones(1, size(data,2)/4)
    velocityScale * ones(1, size(data,2)/4)
    accelerationScale * ones(1, size(data,2)/4)
    jerkScale * ones(1, size(data,2)/4)
    ];

data = data .* scales;
end

function predictions = applyConstraints(predictions, currentState)
% Apply physical constraints to predictions
% Get configuration
config = config.getConfig();

% Velocity constraints
predictions.velocities = max(0, ...
    min(predictions.velocities, ...
    config.truck.max_velocity));

% Acceleration constraints
predictions.accelerations = max(...
    config.truck.max_deceleration, ...
    min(predictions.accelerations, ...
    config.truck.max_acceleration));

% Jerk constraints
predictions.jerks = max(-config.truck.max_jerk, ...
    min(predictions.jerks, ...
    config.truck.max_jerk));

% Position constraints (maintain minimum following distance)
for i = 2:length(predictions.positions)
    minDistance = config.truck.min_safe_distance + ...
        config.safety.min_following_time * predictions.velocities(i);

    if predictions.positions(i-1) - predictions.positions(i) < minDistance
        % Adjust position to maintain minimum distance
        predictions.positions(i) = predictions.positions(i-1) - minDistance;

        % Adjust velocity to avoid future violations
        predictions.velocities(i) = min(predictions.velocities(i), ...
            predictions.velocities(i-1));
    end
end

% Ensure predictions are physically consistent with current state
dt = 0.1; % Assumed time step
predictions.positions = currentState.positions + ...
    currentState.velocities * dt + ...
    0.5 * currentState.accelerations * dt^2 + ...
    (1/6) * predictions.jerks * dt^3;

predictions.velocities = currentState.velocities + ...
    currentState.accelerations * dt + ...
    0.5 * predictions.jerks * dt^2;

predictions.accelerations = currentState.accelerations + ...
    predictions.jerks * dt;
end