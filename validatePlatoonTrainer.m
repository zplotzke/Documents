function validatePlatoonTrainer(trainer, config)
    % VALIDATEPLATOONTRAINER Validate platoon trainer configuration and state
    %
    % This function performs comprehensive validation of a PlatoonTrainer
    % instance, including:
    % - Network configuration validation
    % - Training metrics validation
    % - Dataset validation
    % - Model state validation
    %
    % Parameters:
    %   trainer - PlatoonTrainer instance to validate
    %   config - Configuration structure containing training parameters
    %
    % Throws:
    %   - MException if validation fails
    %
    % Author: zplotzke
    % Last Modified: 2025-02-15 03:21:55 UTC
    % Version: 1.0.2
    
    % Get logger instance
    logger = utils.Logger.getLogger('PlatoonTrainerValidator');
    logger.info('Starting platoon trainer validation');
    
    try
        % Validate network configuration
        validateNetworkConfig(trainer.NetworkConfig, config.training, logger);
        
        % Validate training metrics if network is trained
        if trainer.IsNetworkTrained
            validateTrainingMetrics(trainer.TrainingMetrics, config.training, logger);
        end
        
        % Validate dataset if available
        if trainer.DatasetSize > 0
            validateDataset(trainer, config.training, logger);
        end
        
        % Validate model state
        validateModelState(trainer, logger);
        
        logger.info('Platoon trainer validation completed successfully');
        
    catch ME
        logger.error('Validation failed: %s', ME.message);
        rethrow(ME);
    end
end

function validateNetworkConfig(networkConfig, trainingConfig, logger)
    % Validate network configuration matches training config
    logger.debug('Validating network configuration');
    
    assert(networkConfig.lstm_hidden_units == trainingConfig.lstm_hidden_units, ...
        'LSTM hidden units mismatch: expected %d, got %d', ...
        trainingConfig.lstm_hidden_units, networkConfig.lstm_hidden_units);
    
    assert(networkConfig.max_epochs == trainingConfig.max_epochs, ...
        'Max epochs mismatch: expected %d, got %d', ...
        trainingConfig.max_epochs, networkConfig.max_epochs);
    
    assert(networkConfig.mini_batch_size == trainingConfig.mini_batch_size, ...
        'Mini batch size mismatch: expected %d, got %d', ...
        trainingConfig.mini_batch_size, networkConfig.mini_batch_size);
    
    assert(abs(networkConfig.learning_rate - trainingConfig.learning_rate) < 1e-6, ...
        'Learning rate mismatch: expected %.6f, got %.6f', ...
        trainingConfig.learning_rate, networkConfig.learning_rate);
    
    logger.debug('Network configuration validation completed');
end

function validateTrainingMetrics(metrics, trainingConfig, logger)
    % Validate training metrics are reasonable
    logger.debug('Validating training metrics');
    
    % Validate RMSE values
    assert(~isempty(metrics.trainRMSE), 'Training RMSE missing');
    assert(~isempty(metrics.valRMSE), 'Validation RMSE missing');
    assert(all(metrics.trainRMSE > 0), 'Invalid training RMSE values');
    assert(all(metrics.valRMSE > 0), 'Invalid validation RMSE values');
    
    % Validate training time
    assert(metrics.trainTime > 0, 'Invalid training time');
    
    % Validate epochs
    assert(metrics.epochs > 0 && metrics.epochs <= trainingConfig.max_epochs, ...
        'Invalid number of epochs: %d', metrics.epochs);
    
    % Validate final loss
    assert(metrics.finalLoss > 0 && ~isinf(metrics.finalLoss), ...
        'Invalid final loss: %.6f', metrics.finalLoss);
    
    logger.debug('Training metrics validation completed');
end

function validateDataset(trainer, trainingConfig, logger)
    % Validate dataset properties
    logger.debug('Validating dataset');
    
    % Check dataset size
    assert(trainer.DatasetSize >= trainingConfig.mini_batch_size, ...
        'Dataset size (%d) smaller than mini-batch size (%d)', ...
        trainer.DatasetSize, trainingConfig.mini_batch_size);
    
    % Check data distribution if available
    if ismethod(trainer, 'getDataDistribution')
        dist = trainer.getDataDistribution();
        validateDataDistribution(dist, logger);
    end
    
    logger.debug('Dataset validation completed');
end

function validateModelState(trainer, logger)
    % Validate model state
    logger.debug('Validating model state');
    
    if trainer.IsNetworkTrained
        % Verify model can make predictions
        assert(ismethod(trainer, 'predictNextState'), ...
            'Trained model missing prediction method');
        
        % Verify model weights exist
        assert(~isempty(trainer.getNetwork()), 'Model weights missing');
    end
    
    logger.debug('Model state validation completed');
end

function validateDataDistribution(distribution, logger)
    % Validate data distribution properties
    assert(isstruct(distribution), 'Invalid distribution format');
    assert(isfield(distribution, 'mean') && isfield(distribution, 'std'), ...
        'Missing distribution statistics');
    
    % Log distribution statistics
    logger.debug('Data distribution - Mean: %.4f, Std: %.4f', ...
        mean(distribution.mean), mean(distribution.std));
end