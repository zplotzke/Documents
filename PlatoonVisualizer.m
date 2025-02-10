classdef PlatoonVisualizer < handle
    % PLATOONVISUALIZER Visualization class for truck platoon simulation
    %
    % This class handles real-time visualization of truck platoon simulation results,
    % including position, velocity, acceleration, jerk, and safety distances,
    % with progress tracking over a one-mile journey.
    %
    % Author: zplotzke
    % Last Modified: 2025-02-10 04:51:07 UTC
    % Version: 1.5.8

    properties
        config          % Configuration structure
        figure_handle   % Handle to main figure
        truck_patches   % Array of patch objects for trucks
        info_text      % Handle to information text
        road_limits    % Full road visualization limits [xmin xmax ymin ymax]
        view_window    % Current view window for animation [xmin xmax ymin ymax]
        truck_width    % Width of truck visualization
        animation_ax   % Handle to animation subplot
        velocity_ax    % Handle to velocity subplot
        accel_ax      % Handle to acceleration subplot
        jerk_ax       % Handle to jerk subplot
        safety_ax     % Handle to safety subplot
        time_line     % Handle to vertical time lines in plots
        velocity_lines % Handles to velocity plot lines
        accel_lines   % Handles to acceleration plot lines
        jerk_lines    % Handles to jerk plot lines
        safety_lines  % Handles to safety distance plot lines
        road_patches  % Handles to road visualization elements
        total_distance % Total distance of the road in meters
    end

    methods
        function obj = PlatoonVisualizer(varargin)
            % Constructor for PlatoonVisualizer
            % Usage: obj = PlatoonVisualizer() or obj = PlatoonVisualizer(config)

            % Set default configuration if none provided
            if nargin > 0
                obj.config = varargin{1};
            else
                % Default configuration
                obj.config.truck.num_trucks = 4;
                obj.config.truck.length = [15 15 15 15];
                obj.config.truck.initial_speed = 20;
                obj.config.truck.desired_gap = 20;
                obj.config.safety.min_safe_distance = 10;
                obj.config.simulation.frame_rate = 10;
                obj.config.truck.max_relative_velocity = 5;
            end

            % Set visualization parameters
            obj.truck_width = 2.5;      % meters
            obj.total_distance = 1609.34; % 1 mile in meters
            road_width = 10;            % meters

            % Calculate initial view width based on platoon length
            total_platoon_length = sum(obj.config.truck.length) + ...
                (obj.config.truck.num_trucks - 1) * obj.config.truck.desired_gap;
            view_width = max(300, total_platoon_length * 1.5);  % At least 300m or 1.5x platoon length

            % Set full road limits and initial view window
            obj.road_limits = [-20 obj.total_distance -road_width/2 road_width/2];
            obj.view_window = [-20 view_width -road_width/2 road_width/2];

            % Create figure
            obj.figure_handle = figure('Name', 'Truck Platoon Simulation Results', ...
                'NumberTitle', 'off', ...
                'Color', [1 1 1], ...
                'Position', [100 100 1200 1000]);
        end

        function visualize(obj, state)
            % Visualize final simulation state with synchronized animation

            clf(obj.figure_handle);

            % Calculate acceleration and jerk
            [accelerations, jerks] = obj.calculateKinematics(state.timeHistory.times, ...
                state.timeHistory.velocities);

            % Create subplots with adjusted spacing
            % Format: subplot('Position', [left bottom width height])
            obj.animation_ax = subplot('Position', [0.15 0.82 0.75 0.12]); % Animation plot
            obj.initializeAnimationPlot(state);

            obj.velocity_ax = subplot('Position', [0.15 0.63 0.75 0.12]); % Velocity plot
            obj.initializeVelocityPlot(state.timeHistory.times, ...
                state.timeHistory.velocities);

            obj.accel_ax = subplot('Position', [0.15 0.44 0.75 0.12]); % Acceleration plot
            obj.initializeAccelPlot(state.timeHistory.times, accelerations);

            obj.jerk_ax = subplot('Position', [0.15 0.25 0.75 0.12]); % Jerk plot
            obj.initializeJerkPlot(state.timeHistory.times, jerks);

            obj.safety_ax = subplot('Position', [0.15 0.06 0.75 0.12]); % Safety distances
            obj.initializeSafetyPlot(state.timeHistory.times, ...
                state.timeHistory.positions, ...
                state.lengths);

            % Add timestamp information
            annotation('textbox', [0 0 1 0.02], ...
                'String', sprintf('Final Simulation Results\nTimestamp: %s\nAuthor: %s', ...
                '2025-02-10 04:51:07', 'zplotzke'), ...
                'EdgeColor', 'none', ...
                'HorizontalAlignment', 'center');

            % Synchronized animation
            obj.animateSimulation(state.timeHistory.times, ...
                state.timeHistory.positions, ...
                state.timeHistory.velocities, ...
                accelerations, ...
                jerks, ...
                state.lengths);

            % Export figure
            output_file = 'platoon_final_simulation.png';
            try
                % Ensure figure is updated
                drawnow;
                % Save figure
                print(obj.figure_handle, '-dpng', '-r300', output_file);
            catch ME
                warning(ME.identifier, '%s', ME.message);
            end
        end

        function color = getTruckColor(obj, index)
            % Get color for truck visualization
            colors = {[0.2 0.4 0.8],  % Blue
                [0.8 0.2 0.2],  % Red
                [0.2 0.8 0.2],  % Green
                [0.8 0.8 0.2],  % Yellow
                [0.8 0.2 0.8],  % Magenta
                [0.2 0.8 0.8]}; % Cyan
            color = colors{mod(index-1, length(colors)) + 1};
        end
    end

    methods (Access = private)
        function initializeAnimationPlot(obj, state)
            % Initialize animation plot with improved road visualization
            % Last Modified: 2025-02-10 05:16:23
            % Author: zplotzke

            axes(obj.animation_ax);
            hold on;

            % Road visualization with realistic dimensions
            lane_width = 3.7;       % Standard US highway lane width (meters)
            shoulder_width = 2.5;    % Standard shoulder width (meters)
            road_width = (lane_width * 2) + (shoulder_width * 2);  % Two lanes plus shoulders
            road_y = [-road_width/2, road_width/2];
            road_x = [0, obj.total_distance];

            % Create the road surface with asphalt-like gray color
            fill([road_x(1), road_x(2), road_x(2), road_x(1)], ...
                [road_y(1), road_y(1), road_y(2), road_y(2)], ...
                [0.85 0.85 0.85], ...
                'EdgeColor', 'none', ...
                'DisplayName', 'Road Surface');

            % Add lane markings (dashed lines)
            lane_mark_length = 3;
            lane_mark_gap = 6;
            mark_pattern = 0:lane_mark_length+lane_mark_gap:obj.total_distance;

            % Draw center line
            for i = 1:length(mark_pattern)-1
                if mod(i,2) == 1
                    % Center line
                    plot([mark_pattern(i), mark_pattern(i+1)], ...
                        [0, 0], ...
                        'w-', 'LineWidth', 2, ...
                        'HandleVisibility', 'off');
                end
            end

            % Draw solid shoulder lines
            plot([0, obj.total_distance], [-lane_width, -lane_width], 'w-', 'LineWidth', 2, 'HandleVisibility', 'off');
            plot([0, obj.total_distance], [lane_width, lane_width], 'w-', 'LineWidth', 2, 'HandleVisibility', 'off');

            % Set axis properties for top-down view with realistic scale
            ylim([-road_width, road_width]);  % Full road width plus small margin
            xlabel('Distance (m)', 'FontSize', 10);
            ylabel('Lateral Position (m)', 'FontSize', 10);

            title('Truck Platoon Movement (Top View)', ...
                'FontSize', 14, ...
                'FontWeight', 'bold', ...
                'Units', 'normalized', ...
                'Position', [0.5, 1.1, 0]);

            grid on;

            % Add distance markers every quarter mile
            quarter_mile = 402.336;  % meters
            for d = 0:quarter_mile:obj.total_distance
                % Vertical reference line
                xline(d, 'k:', 'HandleVisibility', 'off', 'Alpha', 0.3);

                % Distance marker text
                if d == 0
                    label = 'Start';
                elseif d == obj.total_distance
                    label = 'One Mile';
                else
                    label = sprintf('%.0fm', d);
                end

                text(d, -road_width*0.8, label, ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 8, ...
                    'Color', [0.3 0.3 0.3]);
            end

            set(gca, 'Layer', 'top');
            legend('show', 'Location', 'northwest');

            % Use normal axis scaling
            axis normal;

            % Set x-axis limits with margin
            xlim([-50, obj.total_distance + 50]);
        end

        function [accelerations, jerks] = calculateKinematics(obj, times, velocities)
            % Calculate acceleration and jerk from velocity data
            dt = diff(times);
            accelerations = zeros(size(velocities));
            jerks = zeros(size(velocities));

            % Calculate acceleration
            for i = 1:size(velocities, 1)
                % First derivative for acceleration
                dv = diff(velocities(i,:));
                accelerations(i,1:end-1) = dv ./ dt;
                accelerations(i,end) = accelerations(i,end-1);

                % Second derivative for jerk
                da = diff(accelerations(i,:));
                jerks(i,1:end-1) = da ./ dt;
                jerks(i,end) = jerks(i,end-1);
            end
        end

        function initializeVelocityPlot(obj, times, velocities)
            axes(obj.velocity_ax);
            num_trucks = size(velocities, 1);
            hold on;

            % Clear any existing plots
            cla;

            % Initialize line objects array
            obj.velocity_lines = gobjects(num_trucks, 1);

            % Create plots and store handles
            for i = 1:num_trucks
                obj.velocity_lines(i) = plot(times(1), velocities(i,1), ...
                    'LineWidth', 1.5, 'Color', obj.getTruckColor(i), ...
                    'DisplayName', sprintf('Truck %d', i));
            end

            title('Velocity', 'FontSize', 12);
            xlabel('Time (s)');
            ylabel('Velocity (m/s)');

            % Create legend using only the truck line handles
            legend(obj.velocity_lines, 'Location', 'eastoutside');

            grid on;
            xlim([times(1) times(end)]);
            ylim([min(velocities(:))-1 max(velocities(:))+1]);

            % Add time line after legend creation
            obj.time_line(1) = xline(times(1), 'r-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
        end

        function initializeAccelPlot(obj, times, accelerations)
            axes(obj.accel_ax);
            num_trucks = size(accelerations, 1);
            hold on;

            % Clear any existing plots
            cla;

            % Initialize line objects array
            obj.accel_lines = gobjects(num_trucks, 1);

            % Create plots and store handles
            for i = 1:num_trucks
                obj.accel_lines(i) = plot(times(1), accelerations(i,1), ...
                    'LineWidth', 1.5, 'Color', obj.getTruckColor(i), ...
                    'DisplayName', sprintf('Truck %d', i));
            end

            title('Acceleration', 'FontSize', 12);
            xlabel('Time (s)');
            ylabel('Acceleration (m/s²)');

            % Create legend using only the truck line handles
            legend(obj.accel_lines, 'Location', 'eastoutside');

            grid on;
            xlim([times(1) times(end)]);
            ylim([min(accelerations(:))-0.5 max(accelerations(:))+0.5]);

            % Add time line after legend creation
            obj.time_line(2) = xline(times(1), 'r-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
        end

        function initializeJerkPlot(obj, times, jerks)
            axes(obj.jerk_ax);
            num_trucks = size(jerks, 1);
            hold on;

            % Clear any existing plots
            cla;

            % Initialize line objects array
            obj.jerk_lines = gobjects(num_trucks, 1);

            % Create plots and store handles
            for i = 1:num_trucks
                obj.jerk_lines(i) = plot(times(1), jerks(i,1), ...
                    'LineWidth', 1.5, 'Color', obj.getTruckColor(i), ...
                    'DisplayName', sprintf('Truck %d', i));
            end

            title('Jerk', 'FontSize', 12);
            xlabel('Time (s)');
            ylabel('Jerk (m/s³)');

            % Create legend using only the truck line handles
            legend(obj.jerk_lines, 'Location', 'eastoutside');

            grid on;
            xlim([times(1) times(end)]);
            ylim([min(jerks(:))-0.5 max(jerks(:))+0.5]);

            % Add time line after legend creation
            obj.time_line(3) = xline(times(1), 'r-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
        end

        function initializeSafetyPlot(obj, times, positions, lengths)
            axes(obj.safety_ax);
            num_gaps = size(positions, 1) - 1;
            hold on;

            % Clear any existing plots
            cla;

            safety_history = obj.calculateSafetyHistory(positions, lengths);
            obj.safety_lines = gobjects(num_gaps, 1);

            % Create plots and store handles
            for i = 1:num_gaps
                obj.safety_lines(i) = plot(times(1), safety_history(i,1), ...
                    'LineWidth', 1.5, 'Color', obj.getTruckColor(i), ...
                    'DisplayName', sprintf('Gap %d-%d', i, i+1));
            end

            % Add minimum safe distance line without including it in legend
            yline(obj.config.safety.min_safe_distance, 'r--', ...
                'LineWidth', 1.5, 'HandleVisibility', 'off');

            title('Inter-vehicle Distances', 'FontSize', 12);
            xlabel('Time (s)');
            ylabel('Distance (m)');

            % Create legend with only gap lines
            legend(obj.safety_lines, 'Location', 'eastoutside');

            grid on;
            xlim([times(1) times(end)]);
            ylim([min(safety_history(:))-1 max(safety_history(:))+1]);

            % Add time line after legend creation
            obj.time_line(4) = xline(times(1), 'r-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
        end

        function safety_history = calculateSafetyHistory(obj, positions, lengths)
            % Calculate inter-vehicle distances for all timesteps
            %
            % Parameters:
            %   positions - Matrix of positions [num_trucks x num_timesteps]
            %   lengths - Vector of truck lengths [num_trucks x 1]
            %
            % Returns:
            %   safety_history - Matrix of inter-vehicle distances [(num_trucks-1) x num_timesteps]

            num_trucks = size(positions, 1);
            num_times = size(positions, 2);
            safety_history = zeros(num_trucks - 1, num_times);

            for t = 1:num_times
                for i = 1:(num_trucks - 1)
                    % Distance between front of following truck and rear of leading truck
                    safety_history(i,t) = positions(i,t) - positions(i+1,t) - lengths(i);
                end
            end
        end
        function animateSimulation(obj, times, positions, velocities, accelerations, jerks, lengths)
            % ANIMATESIMULATION Animates the truck platoon simulation
            % Last Modified: 2025-02-10 18:15:43 UTC
            % Author: zplotzke

            % Get number of trucks and frames
            num_frames = length(times);
            num_trucks = size(positions, 1);

            % Calculate safety history at the start
            safety_history = obj.calculateSafetyHistory(positions, lengths);

            % Get truck dimensions for top-down view
            truck_width = 2.6;  % Standard semi-truck width (meters)

            % Calculate frame delay to match simulation time
            frame_delay = diff(times(1:2));

            % Create new figure and axes if needed
            try
                if isempty(obj.animation_ax) || ~isgraphics(obj.animation_ax, 'axes')
                    obj.animation_ax = axes(figure);
                end
            catch
                obj.animation_ax = axes(figure);
            end

            % Initialize truck patches if not already created
            if isempty(obj.truck_patches)
                obj.truck_patches = gobjects(num_trucks, 1);
                axes(obj.animation_ax);
                hold on

                % Create legend entries for trucks
                legend_entries = cell(num_trucks, 1);

                for i = 1:num_trucks
                    % Create patch for each truck (top-down view)
                    y_start = -truck_width/2;
                    y_end = truck_width/2;
                    x_start = positions(i,1);
                    x_end = positions(i,1) + lengths(i);

                    % Define coordinates for rectangle (x,y) pairs
                    x_coords = [x_start, x_end, x_end, x_start];
                    y_coords = [y_start, y_start, y_end, y_end];

                    obj.truck_patches(i) = patch(obj.animation_ax, ...
                        'XData', x_coords, ...
                        'YData', y_coords, ...
                        'FaceColor', obj.getTruckColor(i), ...
                        'EdgeColor', 'black', ...
                        'LineWidth', 1.5, ...
                        'DisplayName', sprintf('Truck %d', i));

                    legend_entries{i} = sprintf('Truck %d', i);
                end

                % Initial axis limits
                ylim(obj.animation_ax, [-6.1, 6.1]); % Road width plus margin
                grid(obj.animation_ax, 'on');
                xlabel(obj.animation_ax, 'Position (m)');
                ylabel(obj.animation_ax, 'Lateral Position (m)');
                title(obj.animation_ax, 'Truck Platoon Animation');

                % Add legend with truck labels
                legend(obj.animation_ax, 'show');
                legend(obj.animation_ax, 'Location', 'northeast');
            end

            % Animation loop
            for frame = 1:num_frames
                try
                    % Find current platoon extents including truck lengths
                    platoon_positions = positions(:,frame);
                    platoon_ends = platoon_positions + lengths';
                    platoon_front = max(platoon_ends);
                    platoon_rear = min(platoon_positions);

                    % Calculate view window - fixed width that moves with platoon
                    window_width = 200;  % Show 200m of road at a time
                    window_center = (platoon_front + platoon_rear) / 2;
                    x_min = window_center - window_width/2;
                    x_max = window_center + window_width/2;

                    % Adjust limits if near boundaries
                    if x_min < 0
                        x_min = 0;
                        x_max = window_width;
                    elseif x_max > obj.total_distance
                        x_max = obj.total_distance;
                        x_min = max(0, x_max - window_width);
                    end

                    % Update each truck
                    for i = 1:num_trucks
                        % Get current position for this truck
                        x_start = positions(i,frame);
                        x_end = x_start + lengths(i);

                        % Update truck visualization
                        x_coords = [x_start, x_end, x_end, x_start];
                        y_coords = [-truck_width/2, -truck_width/2, truck_width/2, truck_width/2];

                        % Update the patch
                        set(obj.truck_patches(i), 'XData', x_coords, 'YData', y_coords);
                    end

                    % Update axis limits if valid
                    valid_limits = isscalar(x_min) && isscalar(x_max) && ...
                        isfinite(x_min) && isfinite(x_max) && ...
                        (x_min < x_max);
                    if valid_limits
                        xlim(obj.animation_ax, [x_min, x_max]);
                    end

                    % Update time lines in all plots
                    for i = 1:4
                        set(obj.time_line(i), 'Value', times(frame));
                    end

                    % Update real-time plots
                    for i = 1:num_trucks
                        % Update velocity plot
                        set(obj.velocity_lines(i), 'XData', times(1:frame), ...
                            'YData', velocities(i,1:frame));

                        % Update acceleration plot
                        set(obj.accel_lines(i), 'XData', times(1:frame), ...
                            'YData', accelerations(i,1:frame));

                        % Update jerk plot
                        set(obj.jerk_lines(i), 'XData', times(1:frame), ...
                            'YData', jerks(i,1:frame));

                        % Update safety plot
                        if i < num_trucks
                            set(obj.safety_lines(i), 'XData', times(1:frame), ...
                                'YData', safety_history(i,1:frame));
                        end
                    end

                    % Force immediate update of the display
                    drawnow();

                    % Add delay for animation timing
                    if frame_delay > 0
                        pause(frame_delay);
                    end

                catch ME
                    warning(ME.identifier, '%s', ME.message);
                    return;
                end
            end

            % Final update
            drawnow();
        end
    end
end