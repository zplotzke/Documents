function verifyLSTMNetwork()
    % Initialize
    config = getConfig();
    logger = Logger(config.simulation.file_names.warning_log, true);
    
    try
        % Load network and test data
        [net, testData] = loadNetworkAndTestData(config, logger);
        
        % Perform verification tests
        results = performVerificationTests(net, testData, config, logger);
        
        % Generate verification report
        generateReport(results, config, logger);
        
    catch ME
        logger.error('Verification failed: %s', ME.message);
        rethrow(ME);
    end
end

function [net, testData] = loadNetworkAndTestData(config, logger)
    logger.info('Loading network and test data...');
    
    % Load trained network
    try
        load(config.simulation.file_names.lstm_model, 'net');
    catch ME
        logger.error('Failed to load LSTM model: %s', ME.message);
        rethrow(ME);
    end
    
    % Load test data
    try
        data = load(config.simulation.file_names.simulation_data);
        % Use last portion of data for testing
        numSequences = size(data.inputs, 3);
        testIdx = floor(numSequences * 0.8) + 1 : numSequences;
        
        testData.X = data.inputs(:,:,testIdx);
        testData.Y = data.outputs(:,:,testIdx);
        
        % Load normalization parameters
        load('norm_params.mat', 'input_params', 'output_params');
        testData.normParams.input = input_params;
        testData.normParams.output = output_params;
        
    catch ME
        logger.error('Failed to load test data: %s', ME.message);
        rethrow(ME);
    end
end

function results = performVerificationTests(net, testData, config, logger)
    logger.info('Performing verification tests...');
    
    % Normalize test data
    X_norm = (testData.X - reshape(testData.normParams.input.mean, [], 1, 1)) ./ ...
        reshape(testData.normParams.input.std, [], 1, 1);
    
    % Get predictions
    Y_pred_norm = predict(net, X_norm);
    
    % Denormalize predictions
    Y_pred = Y_pred_norm .* reshape(testData.normParams.output.std, [], 1, 1) + ...
        reshape(testData.normParams.output.mean, [], 1, 1);
    
    % Calculate metrics
    results = struct();
    results.rmse = sqrt(mean((Y_pred - testData.Y).^2, 'all'));
    results.mae = mean(abs(Y_pred - testData.Y), 'all');
    results.maxError = max(abs(Y_pred - testData.Y), [], 'all');
    
    % Calculate metrics for each component (position, velocity, acceleration)
    numTrucks = config.truck.num_trucks;
    results.position_rmse = calculateComponentRMSE(Y_pred(1:numTrucks,:,:), ...
        testData.Y(1:numTrucks,:,:));
    results.velocity_rmse = calculateComponentRMSE(Y_pred(numTrucks+1:2*numTrucks,:,:), ...
        testData.Y(numTrucks+1:2*numTrucks,:,:));
    results.acceleration_rmse = calculateComponentRMSE(Y_pred(2*numTrucks+1:end,:,:), ...
        testData.Y(2*numTrucks+1:end,:,:));
    
    % Visualize results
    visualizeVerificationResults(Y_pred, testData.Y, results, config);
    
    logger.info('Verification tests completed');
end

function rmse = calculateComponentRMSE(pred, actual)
    rmse = sqrt(mean((pred - actual).^2, 'all'));
end

function visualizeVerificationResults(Y_pred, Y_actual, results, config)
    figure('Name', 'LSTM Verification Results', 'Position', [100 100 1200 800]);
    
    % Plot 1: Position predictions vs actual
    subplot(2,2,1);
    plotComponentComparison(Y_pred(1,:,1), Y_actual(1,:,1), 'Position (m)');
    
    % Plot 2: Velocity predictions vs actual
    subplot(2,2,2);
    plotComponentComparison(Y_pred(config.truck.num_trucks+1,:,1), ...
        Y_actual(config.truck.num_trucks+1,:,1), 'Velocity (m/s)');
    
    % Plot 3: Error histogram
    subplot(2,2,3);
    plotErrorHistogram(Y_pred - Y_actual);
    
    % Plot 4: Performance metrics
    subplot(2,2,4);
    plotPerformanceMetrics(results);
    
    % Save figure
    saveas(gcf, 'verification_results.fig');
    saveas(gcf, 'verification_results.png');
end

function plotComponentComparison(pred, actual, ylabel_text)
    plot(actual, 'b-', 'LineWidth', 1.5);
    hold on;
    plot(pred, 'r--', 'LineWidth', 1.5);
    xlabel('Time Step');
    ylabel(ylabel_text);
    legend('Actual', 'Predicted');
    grid on;
end

function plotErrorHistogram(errors)
    histogram(errors(:), 50, 'Normalization', 'probability');
    xlabel('Prediction Error');
    ylabel('Probability');
    title('Error Distribution');
    grid on;
end

function plotPerformanceMetrics(results)
    metrics = [results.position_rmse, results.velocity_rmse, results.acceleration_rmse];
    bar(metrics);
    xlabel('Component');
    ylabel('RMSE');
    set(gca, 'XTickLabel', {'Position', 'Velocity', 'Acceleration'});
    title('Component-wise RMSE');
    grid on;
end

function generateReport(results, ~, logger)
    logger.info('Generating verification report...');
    
    % Create report file
    reportFile = 'lstm_verification_report.txt';
    fid = fopen(reportFile, 'w');
    
    % Write header
    fprintf(fid, 'LSTM Network Verification Report\n');
    fprintf(fid, 'Generated: %s\n\n', datetime('now'));
    
    % Write overall metrics
    fprintf(fid, 'Overall Performance Metrics:\n');
    fprintf(fid, '- RMSE: %.4f\n', results.rmse);
    fprintf(fid, '- MAE: %.4f\n', results.mae);
    fprintf(fid, '- Maximum Error: %.4f\n\n', results.maxError);
    
    % Write component-wise metrics
    fprintf(fid, 'Component-wise RMSE:\n');
    fprintf(fid, '- Position: %.4f m\n', results.position_rmse);
    fprintf(fid, '- Velocity: %.4f m/s\n', results.velocity_rmse);
    fprintf(fid, '- Acceleration: %.4f m/s²\n', results.acceleration_rmse);
    
    fclose(fid);
    logger.info('Verification report generated: %s', reportFile);
end