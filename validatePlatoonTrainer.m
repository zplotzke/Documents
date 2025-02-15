function validatePlatoonTrainer
% VALIDATEPLATOONTRAINER Validation tests for PlatoonTrainer class
%
% Author: zplotzke
% Last Modified: 2025-02-13 01:58:52 UTC
% Version: 1.0.16

% Initialize logger
logger = utils.Logger.getLogger('validatePlatoonTrainer');
logger.info('Starting PlatoonTrainer validation');

% Get configuration
config = config.getConfig();

% Initialize trainer directly with no config parameter
trainer = core.PlatoonTrainer();

% Display configuration using direct network access
fprintf('\nConfiguration:\n');
fprintf('Network Architecture:\n');
network = trainer.getNetwork();
fprintf('  - Input size: %d\n', network.InputSize);
fprintf('  - Hidden size: %d\n', network.HiddenSize);
fprintf('  - Output size: %d\n', network.OutputSize);

fprintf('\nTraining:\n');
fprintf('  - Max epochs: %d\n', config.training.max_epochs);
fprintf('  - Batch size: %d\n', config.training.mini_batch_size);
fprintf('  - Learning rate: %.4f\n', config.training.learning_rate);
fprintf('  - Train split: %.1f%%\n', config.training.train_split_ratio * 100);

fprintf('\nSimulation:\n');
fprintf('  - Time step: %.2f s\n', config.simulation.time_step);
fprintf('  - Duration: %.1f s\n', config.simulation.duration);
fprintf('  - Trucks: %d\n', config.truck.num_trucks);
fprintf('  - Initial spacing: %.1f m\n', config.truck.initial_spacing);

% Generate synthetic test data
state = struct(...
    'time', 0.0, ...
    'positions', zeros(config.truck.num_trucks, 1), ...
    'velocities', ones(config.truck.num_trucks, 1), ...
    'accelerations', 0.1*ones(config.truck.num_trucks, 1), ...
    'jerks', zeros(config.truck.num_trucks, 1));

% Collect simulation data with realistic behavior
t = 0:config.simulation.time_step:config.simulation.duration;
for i = 1:length(t)
    state.time = t(i);

    % Lead vehicle follows a varying speed profile
    lead_speed = 1 + 0.3 * sin(0.5*t(i)) + 0.1 * cos(2*t(i));

    % Follower vehicles try to maintain spacing
    for v = 1:config.truck.num_trucks
        if v == 1
            target_speed = lead_speed;
        else
            % Try to maintain constant spacing with preceding vehicle
            spacing = state.positions(v-1) - state.positions(v);
            target_speed = state.velocities(v-1) + ...
                0.5*(spacing - config.truck.initial_spacing);
        end

        % PID-like control
        speed_error = target_speed - state.velocities(v);
        state.accelerations(v) = 0.5 * speed_error;  % P control
        state.jerks(v) = 0.1 * state.accelerations(v);  % D control
    end

    % Update states
    state.positions = state.positions + config.simulation.time_step * state.velocities;
    state.velocities = state.velocities + config.simulation.time_step * state.accelerations;
    state.accelerations = state.accelerations + config.simulation.time_step * state.jerks;

    trainer.collectSimulationData(state);
end

fprintf('\nCollected %d samples\n', trainer.DatasetSize);

% Initial validation
if ~trainer.IsNetworkTrained
    fprintf('Network not yet trained - OK\n');
else
    error('Network should not be trained initially');
end

if isstruct(trainer.NetworkConfig) && isstruct(trainer.TrainingMetrics)
    fprintf('Configuration structures initialized - OK\n');
else
    error('Invalid configuration structures');
end

if trainer.DatasetSize >= 100
    fprintf('Sufficient data collected - OK\n');
else
    error('Insufficient data samples (minimum 100 required)');
end

% Train network
try
    trainer.trainNetwork();
    fprintf('\nTraining Results:\n');
    fprintf('----------------\n');
    fprintf('Training completed successfully\n');

    if trainer.IsNetworkTrained
        metrics = trainer.TrainingMetrics;

        fprintf('Training Metrics:\n');
        fprintf('  - Training RMSE:   %.4f\n', metrics.trainRMSE);
        fprintf('  - Validation RMSE: %.4f\n', metrics.valRMSE);
        fprintf('  - Training Time:   %.2f seconds\n', metrics.trainTime);
        fprintf('  - Total Epochs:    %d\n', metrics.epochs);
        fprintf('  - Final Loss:      %.4f\n', metrics.finalLoss);
        fprintf('  - Training Split:  %.1f%%\n', config.training.train_split_ratio * 100);
        fprintf('  - Random Seed:     %d\n', config.simulation.random_seed);

        % Plot learning curves if available
        if isfield(metrics, 'learningCurve')
            figure('Name', 'Training Progress');
            subplot(2,1,1);
            plot(metrics.learningCurve.iterations, ...
                metrics.learningCurve.trainRMSE, 'b-', ...
                metrics.learningCurve.iterations, ...
                metrics.learningCurve.valRMSE, 'r-');
            xlabel('Iteration');
            ylabel('RMSE');
            title(sprintf('Learning Curves (Seed: %d)', config.simulation.random_seed));
            legend('Training', 'Validation', 'Location', 'best');
            grid on;

            % Add loss ratio plot
            subplot(2,1,2);
            ratio = metrics.learningCurve.valRMSE ./ metrics.learningCurve.trainRMSE;
            plot(metrics.learningCurve.iterations, ratio, 'k-');
            xlabel('Iteration');
            ylabel('Validation/Training RMSE Ratio');
            title('Overfitting Indicator');
            yline(3, 'r--', 'Overfitting Threshold');
            grid on;
        end

        % Validation checks
        assert(~isnan(metrics.trainRMSE), 'Training RMSE should not be NaN');
        assert(~isnan(metrics.valRMSE), 'Validation RMSE should not be NaN');
        assert(metrics.trainTime > 0, 'Training time should be positive');
        assert(metrics.epochs > 0, 'Number of epochs should be positive');

        % Check for potential issues
        if metrics.valRMSE > 3 * metrics.trainRMSE
            warning('Possible overfitting detected: validation RMSE (%.4f) > 3x training RMSE (%.4f)', ...
                metrics.valRMSE, metrics.trainRMSE);
            fprintf('\nSuggested remedies for overfitting:\n');
            fprintf('1. Increase dropout rate (currently %.2f)\n', config.training.dropout_rate);
            fprintf('2. Decrease network capacity\n');
            fprintf('3. Collect more training data (currently %d samples)\n', ...
                trainer.DatasetSize);
        end

        if metrics.epochs >= config.training.max_epochs
            warning('Maximum epochs (%d) reached - model might benefit from longer training', ...
                config.training.max_epochs);
        end

        fprintf('\nAll validation checks passed successfully\n');
    else
        error('Network training did not complete');
    end
catch ME
    fprintf('\nValidation failed: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  File: %s, Line: %d, Function: %s\n', ...
            ME.stack(i).file, ...
            ME.stack(i).line, ...
            ME.stack(i).name);
    end
    rethrow(ME);
end
end