function predictions = predictNextState(net, pos, vel, acc, jerk)
    % PREDICTNEXTSTATE Predicts next state using trained LSTM network
    %
    % Author: zplotzke
    % Created: 2025-02-08 02:06:37 UTC
    
    try
        % Load normalization parameters
        norm_params = load('output/models/norm_params.mat');
        
        % Prepare input in correct format
        input = [
            pos(1);              % Lead truck position
            vel(1);              % Lead truck velocity
            acc(1);              % Lead truck acceleration
            jerk(1);            % Lead truck jerk
            diff(pos);          % Relative positions
            diff(vel);          % Relative velocities
            diff(acc);          % Relative accelerations
            diff(jerk)          % Relative jerks
        ];
        
        % Normalize input
        input_norm = (input - norm_params.input_params.mean) ./ norm_params.input_params.std;
        
        % Get prediction (reshape to match training format)
        pred_norm = predict(net, reshape(input_norm, size(input_norm,1), 1));
        
        % Denormalize prediction
        pred = pred_norm .* norm_params.output_params.std + norm_params.output_params.mean;
        
        % Extract predictions
        numTrucks = length(pos);
        predictions = struct();
        predictions.lead_truck = struct(...
            'position', pred(1), ...
            'velocity', pred(2), ...
            'acceleration', pred(3), ...
            'jerk', pred(4));
        
        % Convert relative predictions back to absolute for following trucks
        rel_indices = 5:4:length(pred);
        predictions.following_trucks = struct(...
            'relative_distances', pred(rel_indices), ...
            'relative_velocities', pred(rel_indices+1), ...
            'relative_accelerations', pred(rel_indices+2), ...
            'relative_jerks', pred(rel_indices+3));
        
    catch ME
        error('Prediction failed: %s', ME.message);
    end
end