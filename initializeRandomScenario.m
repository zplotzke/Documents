function [positions, velocities, accelerations, jerks] = initializeRandomScenario(config, isTraining)
    % INITIALIZERANDOMSCENARIO Initialize scenario for platoon
    % Always starts from safe standard positions, but allows variations in
    % accelerations and jerks during training to develop unsafe conditions
    %
    % Author: zplotzke
    % Created: 2025-02-08 03:11:24 UTC
    
    num_trucks = config.truck.num_trucks;
    
    % Initialize arrays
    positions = zeros(num_trucks, 1);
    velocities = zeros(num_trucks, 1);
    accelerations = zeros(num_trucks, 1);
    jerks = zeros(num_trucks, 1);
    
    % Standard safe spacing between trucks
    safe_distance = config.truck.length + config.safety.min_safe_distance + config.truck.desired_gap;
    
    % Always start with standard safe positions
    % Position trucks from front to back with exact safe spacing
    for i = 1:num_trucks
        positions(i) = safe_distance * (num_trucks - i);
    end
    
    % Always start with the standard velocity
    velocities(:) = config.truck.initial_speed;
    
    if ~isTraining
        % For actual simulation, start with zero accelerations and jerks
        accelerations(:) = 0;
        jerks(:) = 0;
    else
        % For training, introduce small accelerations and jerks that will
        % cause safety violations to develop over time
        
        % Initialize lead truck with small variations
        accelerations(1) = (rand - 0.5) * config.safety.max_acceleration * 0.2;
        jerks(1) = (rand - 0.5) * config.safety.max_jerk * 0.2;
        
        % Initialize follower trucks with variations that will lead to interesting scenarios
        for i = 2:num_trucks
            % Add small accelerations that will develop into safety issues
            accelerations(i) = (rand - 0.5) * config.safety.max_acceleration * 0.3;
            
            % Add small jerks for dynamic behavior
            jerks(i) = (rand - 0.5) * config.safety.max_jerk * 0.3;
        end
    end
    
    % Verify initial conditions are safe
    for i = 1:(num_trucks-1)
        distance = positions(i) - positions(i+1) - config.truck.length;
        rel_velocity = velocities(i) - velocities(i+1);
        
        assert(distance >= config.safety.min_safe_distance, ...
            'Initial distance violation between trucks %d and %d: %.2f m', i, i+1, distance);
        assert(abs(rel_velocity) <= config.truck.max_relative_velocity, ...
            'Initial velocity violation between trucks %d and %d: %.2f m/s', i, i+1, rel_velocity);
    end
end