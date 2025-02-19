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
% Last Modified: 2025-02-19 15:56:45 UTC
% Version: 1.1.10

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
    obj.config = config.getConfig();  % Direct call to getConfig
    trainerConfig = config.trainer;

    % Verify required config fields exist
    validateConfigFields(trainerConfig);

    % Create trainer instance with config
    trainer = core.PlatoonTrainer();

    % Run validations
    validateTrainerSetup(trainer, trainerConfig);
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

function validateConfigFields(trainerConfig)
% VALIDATECONFIGFIELDS Verify all required configuration fields exist
%
% Args:
%   trainerConfig: The trainer configuration structure

requiredFields = {'batch_size', 'epochs', 'validation_split', ...
    'learning_rate', 'optimizer', 'loss_function', ...
    'early_stopping_patience', 'min_delta'};

for i = 1:length(requiredFields)
    assert(isfield(trainerConfig, requiredFields{i}), ...
        'Missing required config field: %s', requiredFields{i});
end
end

function validateTrainerSetup(trainer, config)
% VALIDATETRAINERSETUP Verify trainer initialization and configuration
%
% Args:
%   trainer: The PlatoonTrainer instance
%   config: Configuration structure

% Verify trainer initialization
assert(~isempty(trainer.getNetwork()), 'Network not initialized');

% Verify configuration
trainConfig = trainer.getTrainingConfig();
assert(trainConfig.batch_size == config.batch_size, ...
    'Batch size mismatch. Expected %d, got %d', ...
    config.batch_size, trainConfig.batch_size);
assert(trainConfig.epochs == config.epochs, ...
    'Epochs mismatch. Expected %d, got %d', ...
    config.epochs, trainConfig.epochs);
assert(abs(trainConfig.validation_split - config.validation_split) < 1e-6, ...
    'Validation split mismatch. Expected %.2f, got %.2f', ...
    config.validation_split, trainConfig.validation_split);
assert(strcmp(trainConfig.optimizer, config.optimizer), ...
    'Optimizer mismatch. Expected %s, got %s', ...
    config.optimizer, trainConfig.optimizer);
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
inputSize = trainer.getNetwork().getInputSize();
outputSize = trainer.getNetwork().getOutputSize();

features = rand(inputSize, numSamples);
targets = rand(outputSize, numSamples);

% Measure preparation time
tic;
[trainData, valData] = trainer.prepareData(features, targets);
prepTime = toc;

% Validate data split
assert(~isempty(trainData), 'Training data preparation failed');
assert(~isempty(valData), 'Validation data preparation failed');

% Verify data dimensions
assert(size(trainData.features, 1) == inputSize, ...
    'Training features dimension mismatch');
assert(size(trainData.targets, 1) == outputSize, ...
    'Training targets dimension mismatch');

% Calculate metrics
metrics = struct();
metrics.preparation_time = prepTime;
metrics.train_samples = size(trainData.features, 2);
metrics.val_samples = size(valData.features, 2);
metrics.memory_usage = (whos('trainData','valData').bytes) / 1024; % KB
metrics.input_size = inputSize;
metrics.output_size = outputSize;
end

function metrics = validateTrainingProcess(trainer)
% VALIDATETRAININGPROCESS Verify training functionality
%
% Args:
%   trainer: The PlatoonTrainer instance
%
% Returns:
%   metrics: Structure containing training metrics

% Create minimal training dataset
numSamples = 50;
features = rand(trainer.getNetwork().getInputSize(), numSamples);
targets = rand(trainer.getNetwork().getOutputSize(), numSamples);

% Measure training time
tic;
history = trainer.train(features, targets, 1);
trainTime = toc;

% Validate training history
assert(isstruct(history), 'Training history should be a structure');
assert(isfield(history, 'loss'), 'Training history missing loss field');
assert(all(isfinite(history.loss)), 'Training loss contains non-finite values');

% Calculate metrics
metrics = struct();
metrics.training_time = trainTime;
metrics.final_loss = history.loss(end);
metrics.epochs_completed = length(history.loss);
metrics.samples_per_second = numSamples / trainTime;
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

% Create test data
numTestSamples = 20;
features = rand(trainer.getNetwork().getInputSize(), numTestSamples);
targets = rand(trainer.getNetwork().getOutputSize(), numTestSamples);

% Measure evaluation time
tic;
evalMetrics = trainer.evaluate(features, targets);
evalTime = toc;

% Validate metrics
assert(isstruct(evalMetrics), 'Evaluation metrics should be a structure');
assert(isfield(evalMetrics, 'mse'), 'MSE metric not found');
assert(isfield(evalMetrics, 'mae'), 'MAE metric not found');
assert(isfinite(evalMetrics.mse), 'MSE contains non-finite values');
assert(isfinite(evalMetrics.mae), 'MAE contains non-finite values');

% Calculate metrics
metrics = struct();
metrics.evaluation_time = evalTime;
metrics.mse = evalMetrics.mse;
metrics.mae = evalMetrics.mae;
metrics.samples_per_second = numTestSamples / evalTime;
metrics.prediction_latency = evalTime / numTestSamples;
end