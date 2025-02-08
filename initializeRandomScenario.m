function [positions, velocities, accelerations, jerks] = initializeRandomScenario(config)
    % INITIALIZERANDOMSCENARIO Initialize trucks with standard starting positions
    %
    % Author: zplotzke
    % Created: 2025-02-08 05:52:31 UTC
    
    num_trucks = config.truck.num_trucks;
    
    % Initialize positions with fixed spacing
    base_position = 0;  % Lead truck always starts at position 0
    standard_spacing = config.truck.desired_gap + config.truck.length;  % Fixed initial gap
    
    positions = zeros(num_trucks, 1);
    for i = 1:num_trucks
        positions(i) = base_position - (i-1) * standard_spacing;
    end
    
    % Initialize all trucks with the same initial speed
    velocities = ones(num_trucks, 1) * config.truck.initial_speed;
    
    % Initialize with zero acceleration and jerk
    accelerations = zeros(num_trucks, 1);
    jerks = zeros(num_trucks, 1);
end