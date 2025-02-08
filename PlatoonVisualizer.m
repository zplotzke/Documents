classdef PlatoonVisualizer < handle
    % PLATOONVISUALIZER Visualization class for truck platoon simulation
    %
    % This class handles the real-time visualization of the truck platoon,
    % including optional video recording capabilities.
    %
    % Author: zplotzke
    % Created: 2025-02-08 06:05:02 UTC
    
    properties
        config          % Configuration structure
        figure_handle   % Handle to main figure
        truck_patches   % Array of patch objects for trucks
        info_text      % Handle to information text
        video_writer   % VideoWriter object for saving video
        road_limits    % Visualization limits [xmin xmax ymin ymax]
        truck_width    % Width of truck visualization
    end
    
    methods
        function obj = PlatoonVisualizer(config)
            % Constructor for PlatoonVisualizer
            obj.config = config;
            
            % Set visualization parameters
            obj.truck_width = 2.5;  % meters
            road_length = 200;      % meters
            road_width = 10;        % meters
            obj.road_limits = [-20 road_length -road_width/2 road_width/2];
            
            % Create figure
            obj.figure_handle = figure('Name', 'Truck Platoon Simulation', ...
                'NumberTitle', 'off', ...
                'Color', [1 1 1], ...
                'Position', [100 100 1200 400]);
            
            % Initialize axis
            ax = axes('Parent', obj.figure_handle);
            axis(obj.road_limits);
            hold(ax, 'on');
            grid(ax, 'on');
            xlabel(ax, 'Position (m)');
            ylabel(ax, 'Lateral Position (m)');
            
            % Draw road
            fill([obj.road_limits(1) obj.road_limits(2) obj.road_limits(2) obj.road_limits(1)], ...
                [0 0 obj.truck_width/2 obj.truck_width/2], ...
                [0.8 0.8 0.8], 'EdgeColor', 'none');
            
            % Create truck visualizations
            obj.truck_patches = gobjects(config.truck.num_trucks, 1);
            for i = 1:config.truck.num_trucks
                % Create truck rectangle
                truck_color = obj.config.visualization.truck_colors{i};
                obj.truck_patches(i) = rectangle('Position', [0 -obj.truck_width/2 ...
                    config.truck.length obj.truck_width], ...
                    'FaceColor', truck_color, ...
                    'EdgeColor', 'k');
            end
            
            % Add information text
            obj.info_text = text(obj.road_limits(1) + 5, obj.road_limits(4) - 1, '', ...
                'FontSize', 10);
            
            % Initialize video writer if enabled
            if config.visualization.save_video
                obj.video_writer = VideoWriter(config.visualization.video_filename, 'MPEG-4');
                obj.video_writer.FrameRate = config.simulation.frame_rate;
                open(obj.video_writer);
            end
        end
        
        function update(obj, positions, velocities, current_time)
            % Update visualization with current state
            %
            % Parameters:
            %   positions - Current positions of all trucks
            %   velocities - Current velocities of all trucks
            %   current_time - Current simulation time
            
            % Update truck positions
            for i = 1:length(positions)
                set(obj.truck_patches(i), 'Position', ...
                    [positions(i) -obj.truck_width/2 ...
                    obj.config.truck.length obj.truck_width]);
            end
            
            % Update information text
            info_str = sprintf('Time: %.2fs\nLead Truck Speed: %.1f km/h', ...
                current_time, velocities(1) * 3.6);
            set(obj.info_text, 'String', info_str);
            
            % Update axis limits to follow lead truck
            lead_pos = positions(1);
            window_width = diff(obj.road_limits(1:2));
            if lead_pos > obj.road_limits(2) - window_width/4
                obj.road_limits(1:2) = obj.road_limits(1:2) + window_width/4;
                axis(obj.road_limits);
            end
            
            % Force drawing update
            drawnow;
        end
        
        function saveFrame(obj, frame_number)
            % Save current frame if video recording is enabled
            if ~isempty(obj.video_writer) && obj.video_writer.IsOpen
                frame = getframe(obj.figure_handle);
                writeVideo(obj.video_writer, frame);
            end
        end
        
        function delete(obj)
            % Destructor - Clean up video writer
            if ~isempty(obj.video_writer) && obj.video_writer.IsOpen
                close(obj.video_writer);
            end
            
            % Close figure if it exists
            if isvalid(obj.figure_handle)
                close(obj.figure_handle);
            end
        end
    end
end