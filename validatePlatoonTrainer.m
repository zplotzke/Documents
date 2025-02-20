function results = validatePlatoonTrainer()
% VALIDATEPLATOONTRAINER Validation tests for platoon trainer
%
% Validates the platoon trainer functionality including:
% - Configuration setup
% - Data preparation
% - Training process
% - Model evaluation
%
% Returns:
%   results - Structure containing validation results and metrics
%
% Author: zplotzke
% Last Modified: 2025-02-19 19:34:22 UTC
% Version: 1.1.17

% Initialize logger
logger = utils.Logger.getLogger('PlatoonTrainer');
logger.info('Starting platoon trainer validation');

% Initialize results structure before try block
results = struct('passed', false, ...
    'messages', {{}}, ...
    'warnings', {{}}, ...
    'metrics', struct());

try
    % Get configuration using the proper function call
    cfg = config.getConfig();

    % Create trainer instance from core package
    trainer = core.PlatoonTrainer();

    % Run validations
    validateTrainerSetup(trainer);
    results.metrics.data_prep = validateDataPreparation(trainer);
    results.metrics.training = validateTrainingProcess(trainer);
    results.metrics.evaluation = validateModelEvaluation(trainer);

    results.passed = true;
    results.messages{end+1} = 'Platoon trainer validation passed';
    logger.info('Platoon trainer validation completed successfully');

catch ME
    results.passed = false;
    results.messages{end+1} = sprintf('Validation failed: %s', ME.message);
    logger.error('Platoon trainer validation failed: %s', ME.message);
    rethrow(ME);
end
end

function validateTrainerSetup(trainer)
% VALIDATETRAINERSETUP Verify trainer initialization
%
% Args:
%   trainer: The PlatoonTrainer instance

% Verify trainer initialization
assert(~isempty(trainer.getNetwork()), 'Network not initialized');
end

function metrics = validateDataPreparation(trainer)
% VALIDATEDATAPREPARATION Verify data preparation functionality
%
% Args:
%   trainer: The PlatoonTrainer instance
%
% Returns:
%   metrics: Structure containing data preparation metrics

% Create sample data
numSamples = 100;
network = trainer.getNetwork();
inputSize = network.getInputSize();
outputSize = network.getOutputSize();

% Initialize metrics
metrics = struct();
metrics.preparation_time = 0;
metrics.samples_collected = 0;
metrics.memory_usage = 0;
metrics.input_size = inputSize;
metrics.output_size = outputSize;
metrics.samples_per_second = 0;

try
    % Measure preparation time
    tic;

    % Process one sample at a time
    for i = 1:numSamples
        % Create single state sample
        state = struct(...
            'time', i, ...  % Single time value
            'positions', rand(inputSize, 1), ...  % Column vector
            'velocities', rand(inputSize, 1), ...  % Column vector
            'accelerations', rand(inputSize, 1), ... % Column vector
            'jerks', rand(inputSize, 1));  % Column vector

        % Collect the sample
        trainer.collectSimulationData(state);
    end

    prepTime = toc;

    % Get training stats
    stats = trainer.getTrainingStats();

    % Update metrics
    metrics.preparation_time = prepTime;
    metrics.samples_collected = stats.datasetSize;
    metrics.memory_usage = whos('state').bytes / 1024; % KB
    metrics.samples_per_second = numSamples / prepTime;

catch ME
    logger = utils.Logger.getLogger('PlatoonTrainer');
    logger.error('Data preparation failed: %s', ME.message);
    rethrow(ME);
end
end

function metrics = validateTrainingProcess(trainer)
% VALIDATETRAININGPROCESS Verify training functionality
%
% Args:
%   trainer: The PlatoonTrainer instance
%
% Returns:
%   metrics: Structure containing training metrics

% Measure training time
tic;
trainer.trainNetwork();
trainTime = toc;

% Get training metrics
trainStats = trainer.getTrainingStats();
trainMetrics = trainStats.trainingMetrics;

% Calculate metrics
metrics = struct();
metrics.training_time = trainTime;
metrics.final_loss = trainMetrics.finalLoss;
metrics.epochs_completed = trainMetrics.epochs;
metrics.train_rmse = trainMetrics.trainRMSE;
metrics.val_rmse = trainMetrics.valRMSE;
metrics.memory_peak = memory().MemUsedMATLAB / 1024; % KB
end

function metrics = validateModelEvaluation(trainer)
% VALIDATEMODELEVALUATION Verify model evaluation functionality
%
% Args:
%   trainer: The PlatoonTrainer instance
%
% Returns:
%   metrics: Structure containing evaluation metrics

if ~trainer.IsNetworkTrained
    error('validatePlatoonTrainer:UntrainedNetwork', ...
        'Cannot evaluate untrained network');
end

% Create test data
numTestSamples = 20;
network = trainer.getNetwork();
inputSize = network.getInputSize();

% Create simulated test state
testState = struct(...
    'time', (1:numTestSamples)', ...
    'positions', rand(inputSize, numTestSamples), ...
    'velocities', rand(inputSize, numTestSamples), ...
    'accelerations', rand(inputSize, numTestSamples), ...
    'jerks', rand(inputSize, numTestSamples));

% Measure evaluation time
tic;
for i = 1:numTestSamples
    network.predict(testState);
end
evalTime = toc;

% Get training metrics for comparison
trainStats = trainer.getTrainingStats();
trainMetrics = trainStats.trainingMetrics;

% Calculate metrics
metrics = struct();
metrics.evaluation_time = evalTime;
metrics.train_rmse = trainMetrics.trainRMSE;
metrics.val_rmse = trainMetrics.valRMSE;
metrics.samples_per_second = numTestSamples / evalTime;
metrics.prediction_latency = evalTime / numTestSamples * 1000; % ms
metrics.memory_usage = whos('testState').bytes / 1024; % KB
end