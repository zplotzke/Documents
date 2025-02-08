function safetyStatus = checkSafety(pos, vel, acc, jerk, predictions, config)
    safetyStatus = struct();
    
    % Check current distances
    distances = diff(pos);
    safetyStatus.distanceViolation = any(distances < config.safety.min_safe_distance);
    
    % Check predicted distances
    predicted_distances = diff(predictions.positions);
    safetyStatus.predictionViolation = any(predicted_distances < config.safety.min_safe_distance);
    
    % Check velocities
    safetyStatus.velocityViolation = any(abs(diff(vel)) > 5);
    
    % Check accelerations
    safetyStatus.accelerationViolation = any(abs(acc) > 3);
    
    % Check jerks against thresholds
    safetyStatus.jerkViolation = any(abs(jerk) > config.safety.jerk_thresholds(end));
    
    % Overall critical status
    safetyStatus.isCritical = safetyStatus.distanceViolation || ...
        (safetyStatus.predictionViolation && safetyStatus.velocityViolation) || ...
        safetyStatus.jerkViolation;
end