classdef mainSimulation < handle
    % MAINSIMULATION Main simulation class for truck platoon system
    %
    % Author: zplotzke
    % Created: 2025-02-08 04:05:42 UTC

    properties (Access = private)
        config              % Configuration parameters
        logger             % Logger object
        safetyMonitor      % Safety monitoring object
        inputs             % Training data inputs
        outputs            % Training data outputs
    end

    methods
        function obj = mainSimulation(config)
            obj.config = config;
            obj.logger = Logger.getLogger('mainSimulation');
            obj.safetyMonitor = SafetyMonitor(config, obj.logger);
        end

        function run(obj)
            % Main execution method
            try
                % Generate training data
                obj.generateTrainingData();

                % Train the network
                obj.trainNetwork();

            catch ME
                obj.logger.error('Simulation failed: %s', ME.message);
                rethrow(ME);
            end
        end

        function generateTrainingData(obj)
            % Initialize training data arrays
            numTimesteps = obj.config.simulation.frame_rate * obj.config.simulation.final_time;
            numTrucks = obj.config.truck.num_trucks;
            numFeatures = 4 * (numTrucks - 1);  % relative pos, vel, acc, jerk for each following truck
            numSimulations = obj.config.simulation.num_random_simulations;

            obj.inputs = zeros(numFeatures, numTimesteps, numSimulations);
            obj.outputs = zeros(numFeatures, numTimesteps, numSimulations);

            obj.logger.info('Starting random simulations for training data...');
            obj.logger.info('Generating training data with parameters:');
            obj.logger.info('- Number of trucks: %d', numTrucks);
            obj.logger.info('- Number of relative pairs: %d', numTrucks - 1);
            obj.logger.info('- Timesteps per simulation: %d', numTimesteps);
            obj.logger.info('- Number of simulations: %d', numSimulations);

            for sim = 1:numSimulations
                obj.logger.info('Running simulation %d/%d', sim, numSimulations);
                [input_sequence, output_sequence] = obj.runSimulation();
                obj.inputs(:,:,sim) = input_sequence;
                obj.outputs(:,:,sim) = output_sequence;
            end

            % Log final data dimensions
            obj.logger.info('Training data dimensions:');
            obj.logger.info('- Features per timestep: %d', numFeatures);
            obj.logger.info('- Timesteps per sequence: %d', numTimesteps);
            obj.logger.info('- Number of sequences: %d', numSimulations);
            obj.logger.info('- Total data points: %d', numFeatures * numTimesteps * numSimulations);

            % Save training data using object properties
            obj.logger.info('Saving training data...');
            inputs = obj.inputs;  % Create local copies for saving
            outputs = obj.outputs;
            save(obj.config.simulation.file_names.simulation_data, 'inputs', 'outputs', '-v7.3');
            obj.logger.info('Training data generation complete');
        end

        function trainNetwork(obj)
            trainLSTMNetwork(obj.config, obj.logger);
        end
    end

    methods (Access = private)
        function [input_sequence, output_sequence] = runSimulation(obj)
            % Initialize arrays for this simulation
            numTimesteps = obj.config.simulation.frame_rate * obj.config.simulation.final_time;
            numTrucks = obj.config.truck.num_trucks;
            numFeatures = 4 * (numTrucks - 1);

            input_sequence = zeros(numFeatures, numTimesteps);
            output_sequence = zeros(numFeatures, numTimesteps);  % Fixed dimension

            % Initialize truck states with random variations
            positions = zeros(numTrucks, 1);
            velocities = obj.config.truck.initial_speed * ones(numTrucks, 1) + randn(numTrucks, 1);
            accelerations = zeros(numTrucks, 1);
            jerks = zeros(numTrucks, 1);

            % Simulation time step
            dt = 1 / obj.config.simulation.frame_rate;

            % Run simulation
            for t = 1:numTimesteps
                % Update states
                accelerations = accelerations + jerks * dt;
                velocities = velocities + accelerations * dt;
                positions = positions + velocities * dt;

                % Calculate relative states for following trucks
                rel_pos = diff(positions);
                rel_vel = diff(velocities);
                rel_acc = diff(accelerations);
                rel_jerk = diff(jerks);

                % Pack states into feature vector
                feature_idx = 1;
                for i = 1:numTrucks-1
                    input_sequence(feature_idx:feature_idx+3, t) = [
                        rel_pos(i);
                        rel_vel(i);
                        rel_acc(i);
                        rel_jerk(i)
                        ];
                    feature_idx = feature_idx + 4;
                end

                % Check safety conditions
                time = t * dt;
                [is_safe, violations] = obj.safetyMonitor.checkSafetyConditions(positions, velocities, accelerations, jerks);
                if ~is_safe
                    obj.safetyMonitor.logViolations(violations, time);
                end

                % Update control inputs (jerks) based on relative states
                jerks = -0.1 * accelerations - 0.5 * (velocities - obj.config.truck.initial_speed);
            end

            % Set output sequence (for now, same as input for demonstration)
            output_sequence = input_sequence;
        end
    end
end