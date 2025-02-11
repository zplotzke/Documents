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
            catch export_error
                warning('Failed to export figure. Error: %s', export_error.message);
            end
        end

        function color = getTruckColor(~, index)
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
        function initializeAnimationPlot(obj, ~)
            % Initialize animation plot with improved road visualization

            axes(obj.animation_ax);
            hold on;

            % Road visualization with standard lane width
            road_width = 3.5;  % Standard lane width in meters
            road_y = [-road_width/2, road_width/2];
            road_x = [0, obj.total_distance];

            % Create the road surface with asphalt-like gray color
            fill([road_x(1), road_x(2), road_x(2), road_x(1)], ...
                [road_y(1), road_y(1), road_y(2), road_y(2)], ...
                [0.85 0.85 0.85], ...  % Lighter gray for better visibility
                'EdgeColor', 'none', ...
                'DisplayName', 'Road Lane');

            % Add lane markings (dashed lines)
            lane_mark_length = 3;  % 3m marks (standard)
            lane_mark_gap = 6;     % 6m gaps (standard)
            mark_pattern = 0:lane_mark_length+lane_mark_gap:obj.total_distance;

            % Draw dashed white lines on both sides
            for i = 1:length(mark_pattern)-1
                if mod(i,2) == 1
                    % Bottom lane marking
                    plot([mark_pattern(i), mark_pattern(i+1)], ...
                        [road_y(1), road_y(1)], ...
                        'w-', 'LineWidth', 1.5, ...
                        'HandleVisibility', 'off');
                    % Top lane marking
                    plot([mark_pattern(i), mark_pattern(i+1)], ...
                        [road_y(2), road_y(2)], ...
                        'w-', 'LineWidth', 1.5, ...
                        'HandleVisibility', 'off');
                end
            end

            % Set axis properties
            ylim([-road_width*1.2, road_width*1.2]);  % Add some margin around the road
            xlabel('Distance (m)', 'FontSize', 10);

            % Updated title with larger font and raised position
            title('Truck Platoon Movement', ...
                'FontSize', 14, ...          % Increased from 12 to 14
                'FontWeight', 'bold', ...    % Made bold
                'Units', 'normalized', ...   % Use normalized units
                'Position', [0.5, 1.1, 0]); % Raised position

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

                text(d, -road_width*0.9, label, ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 8, ...
                    'Color', [0.3 0.3 0.3]);
            end

            % Keep grid behind the visualization
            set(gca, 'Layer', 'top');

            % Add legend in a clear location
            legend('show', 'Location', 'northwest');

            % Make sure axes are equal for proper scaling
            axis equal;

            % Ensure proper x-axis limits
            xlim([-50, obj.total_distance + 50]);  % Add some margin at start and end
        end

        function [accelerations, jerks] = calculateKinematics(~, times, velocities)
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

            title('Velocity History', 'FontSize', 12);
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

            title('Acceleration History', 'FontSize', 12);
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

            title('Jerk History', 'FontSize', 12);
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

            title('Inter-vehicle Safety Distances', 'FontSize', 12);
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

        function safety_history = calculateSafetyHistory(~, positions, lengths)
            % Calculate safety distance history for all timesteps
            num_times = size(positions, 2);
            num_gaps = size(positions, 1) - 1;
            safety_history = zeros(num_gaps, num_times);

            for t = 1:num_times
                for i = 1:num_gaps
                    safety_history(i,t) = positions(i,t) - positions(i+1,t) - lengths(i);
                end
            end
        end

        function createProgressIndicator(obj)
            % Create a panel for progress indication
            obj.progress_panel = uipanel('Position', [0.1 0.96 0.8 0.03], ...
                'BackgroundColor', 'white', ...
                'BorderType', 'none');

            % Create progress bar background (white rectangle)
            obj.progress_bar = rectangle('Parent', axes('Parent', obj.progress_panel, ...
                'Position', [0 0 1 1], ...
                'Visible', 'off'), ...
                'Position', [0.01 0.1 0.98 0.8], ...
                'FaceColor', [0.9 0.9 0.9], ...
                'EdgeColor', 'k');

            % Create progress fill (blue rectangle)
            obj.progress_fill = rectangle('Parent', get(obj.progress_bar, 'Parent'), ...
                'Position', [0.01 0.1 0 0.8], ...
                'FaceColor', [0.2 0.6 1], ...
                'EdgeColor', 'none');

            % Create progress text
            obj.progress_text = text('Parent', get(obj.progress_bar, 'Parent'), ...
                'Position', [0.5 0.5], ...
                'String', 'Distance: 0.0 m (0.0%)', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle');

            % Set axis properties
            ax = get(obj.progress_bar, 'Parent');
            set(ax, 'XLim', [0 1], 'YLim', [0 1], ...
                'Visible', 'off');
        end

        function updateProgress(obj, current_position)
            % Calculate progress percentage
            progress = max(0, min(1, (current_position - obj.road_limits(1)) / ...
                (obj.total_distance - obj.road_limits(1))));

            % Update progress fill position
            set(obj.progress_fill, 'Position', [0.01 0.1 0.98*progress 0.8]);

            % Update progress text
            set(obj.progress_text, 'String', sprintf('Distance: %.1f m (%.1f%%)', ...
                current_position, progress*100));
        end

        function drawRoad(obj)
            % Draw road with distance markers
            hold on;

            % Draw main road surface
            fill([obj.road_limits(1) obj.road_limits(2) obj.road_limits(2) obj.road_limits(1)], ...
                [0 0 obj.truck_width/2 obj.truck_width/2], ...
                [0.8 0.8 0.8], 'EdgeColor', 'none');

            % Add distance markers every 100 meters
            for d = 0:100:obj.road_limits(2)
                % Draw marker line
                plot([d d], [-obj.truck_width/4 obj.truck_width/4], 'k-');
                % Add distance label
                text(d, -obj.truck_width, sprintf('%dm', d), ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'top');
            end

            % Add mile marker
            text(1609.34, -obj.truck_width*1.5, '1 mile', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'top', ...
                'FontWeight', 'bold');

            hold off;
        end

        function updateViewWindow(obj, lead_position)
            % Update the view window to follow the lead truck
            window_width = obj.view_window(2) - obj.view_window(1);
            margin = window_width * 0.3; % 30% of window width ahead of lead truck

            % Calculate new window limits
            new_center = lead_position + margin;
            new_xmin = new_center - window_width/2;
            new_xmax = new_center + window_width/2;

            % Ensure window stays within road limits
            if new_xmin < obj.road_limits(1)
                new_xmin = obj.road_limits(1);
                new_xmax = new_xmin + window_width;
            elseif new_xmax > obj.road_limits(2)
                new_xmax = obj.road_limits(2);
                new_xmin = new_xmax - window_width;
            end

            % Update view window
            obj.view_window = [new_xmin new_xmax obj.road_limits(3) obj.road_limits(4)];
            axis(obj.animation_ax, obj.view_window);
        end

        function animateSimulation(obj, times, positions, velocities, accelerations, jerks, lengths)
            % Get number of trucks and frames
            num_frames = length(times);
            num_trucks = size(positions, 1);

            % Get truck dimensions
            truck_height = 2; % Fixed height of 2 units for all trucks when viewed from side

            % Define view window size
            window_width = 300; % Increased width of visible window to show more of the road

            % Initialize truck patches if not already created
            if isempty(obj.truck_patches)
                obj.truck_patches = gobjects(num_trucks, 1);
                axes(obj.animation_ax);

                % Set axis properties
                hold on

                for i = 1:num_trucks
                    % Create patch for each truck
                    y_start = -truck_height/2;
                    y_end = truck_height/2;
                    x_start = positions(i,1);
                    x_end = positions(i,1) + lengths(i);

                    % Define coordinates for rectangle (x,y) pairs
                    x_coords = [x_start, x_end, x_end, x_start];
                    y_coords = [y_start, y_start, y_end, y_end];

                    obj.truck_patches(i) = patch('XData', x_coords, 'YData', y_coords, ...
                        'FaceColor', obj.getTruckColor(i), ...
                        'EdgeColor', 'black');
                end

                % Initial axis limits
                ylim([-5, 5]); % Keep y limits as they were
            end

            % Calculate safety distances for plotting
            safety_history = obj.calculateSafetyHistory(positions, lengths);

            % Calculate frame delay to match simulation time
            frame_delay = diff(times(1:2));

            % Animation loop
            for frame = 1:num_frames
                % Update truck positions in animation
                % Find the position range of all trucks in this frame
                min_pos = min(positions(:,frame));
                max_pos = max(positions(:,frame) + lengths'); % Include truck lengths

                % Update each truck
                for i = 1:num_trucks
                    x_start = positions(i,frame);
                    x_end = positions(i,frame) + lengths(i);
                    x_coords = [x_start, x_end, x_end, x_start];
                    set(obj.truck_patches(i), 'XData', x_coords);
                end

                % Update view window to follow trucks - FIXED
                window_center = (min_pos + max_pos) / 2;
                new_xlim = [window_center - window_width/2, window_center + window_width/2];

                % Ensure limits are valid and increasing
                if new_xlim(1) < new_xlim(2)
                    xlim(obj.animation_ax, new_xlim);
                end

                % Update time line in all plots
                for i = 1:4
                    set(obj.time_line(i), 'Value', times(frame));
                end

                % Update real-time plots with accumulated data up to current frame
                for i = 1:num_trucks
                    set(obj.velocity_lines(i), 'XData', times(1:frame), 'YData', velocities(i,1:frame));
                    set(obj.accel_lines(i), 'XData', times(1:frame), 'YData', accelerations(i,1:frame));
                    set(obj.jerk_lines(i), 'XData', times(1:frame), 'YData', jerks(i,1:frame));
                    if i < num_trucks
                        set(obj.safety_lines(i), 'XData', times(1:frame), 'YData', safety_history(i,1:frame));
                    end
                end

                % Update progress bar
                progress = frame / num_frames * 100;
                obj.updateProgress(progress);

                % Force drawing update
                drawnow;

                % Add delay to match simulation time
                pause(frame_delay);
            end

            % Ensure final state is displayed
            drawnow;

            % Update progress bar to show completion
            obj.updateProgress(100);
        end
    end
end