classdef PlatoonVisualizer < handle
    % PLATOONVISUALIZER Visualization class for truck platoon simulation
    %
    % Author: zplotzke
    % Created: 2025-02-08 02:54:41 UTC
    
    properties (Access = private)
        config
        figure
        truckPositionsAxis
        velocityAxis
        accelerationAxis
        jerkAxis
        videoWriter
    end
    
    methods
        function obj = PlatoonVisualizer(config)
            obj.config = config;
            obj.initializeFigure();
            
            if obj.config.visualization.save_video
                obj.initializeVideoWriter();
            end
        end
        
        function updatePlots(obj, t, positions, velocities, accelerations, jerks)
            % Update truck positions
            cla(obj.truckPositionsAxis);
            hold(obj.truckPositionsAxis, 'on');
            
            % Plot each truck as a rectangle
            for i = 1:length(positions)
                rectangle(obj.truckPositionsAxis, 'Position', ...
                    [positions(i), -1, obj.config.truck.length, 2], ...
                    'FaceColor', 'b', 'EdgeColor', 'k');
            end
            
            title(obj.truckPositionsAxis, sprintf('Time: %.2f s', t));
            xlabel(obj.truckPositionsAxis, 'Position (m)');
            xlim(obj.truckPositionsAxis, [min(positions)-50, max(positions)+50]);
            ylim(obj.truckPositionsAxis, [-3, 3]);
            grid(obj.truckPositionsAxis, 'on');
            hold(obj.truckPositionsAxis, 'off');
            
            % Update velocity plot
            plot(obj.velocityAxis, t, velocities, 'o-');
            title(obj.velocityAxis, 'Velocities');
            xlabel(obj.velocityAxis, 'Time (s)');
            ylabel(obj.velocityAxis, 'Velocity (m/s)');
            grid(obj.velocityAxis, 'on');
            
            % Update acceleration plot
            plot(obj.accelerationAxis, t, accelerations, 'o-');
            title(obj.accelerationAxis, 'Accelerations');
            xlabel(obj.accelerationAxis, 'Time (s)');
            ylabel(obj.accelerationAxis, 'Acceleration (m/s^2)');
            grid(obj.accelerationAxis, 'on');
            
            % Update jerk plot
            plot(obj.jerkAxis, t, jerks, 'o-');
            title(obj.jerkAxis, 'Jerks');
            xlabel(obj.jerkAxis, 'Time (s)');
            ylabel(obj.jerkAxis, 'Jerk (m/s^3)');
            grid(obj.jerkAxis, 'on');
            
            drawnow;
            
            % Capture frame if video recording is enabled
            if ~isempty(obj.videoWriter)
                frame = getframe(obj.figure);
                writeVideo(obj.videoWriter, frame);
            end
        end
        
        function delete(obj)
            % Clean up video writer if it exists
            if ~isempty(obj.videoWriter)
                close(obj.videoWriter);
            end
            
            % Close figure if it exists
            if ishandle(obj.figure)
                close(obj.figure);
            end
        end
    end
    
    methods (Access = private)
        function initializeFigure(obj)
            % Create main figure
            obj.figure = figure('Name', 'Truck Platoon Visualization', ...
                'NumberTitle', 'off', ...
                'Position', [100, 100, 1200, 800]);
            
            % Create subplots for different metrics
            obj.truckPositionsAxis = subplot(4,1,1);
            title(obj.truckPositionsAxis, 'Truck Positions');
            xlabel(obj.truckPositionsAxis, 'Position (m)');
            grid(obj.truckPositionsAxis, 'on');
            
            obj.velocityAxis = subplot(4,1,2);
            title(obj.velocityAxis, 'Velocities');
            xlabel(obj.velocityAxis, 'Time (s)');
            ylabel(obj.velocityAxis, 'Velocity (m/s)');
            grid(obj.velocityAxis, 'on');
            hold(obj.velocityAxis, 'on');
            
            obj.accelerationAxis = subplot(4,1,3);
            title(obj.accelerationAxis, 'Accelerations');
            xlabel(obj.accelerationAxis, 'Time (s)');
            ylabel(obj.accelerationAxis, 'Acceleration (m/s^2)');
            grid(obj.accelerationAxis, 'on');
            hold(obj.accelerationAxis, 'on');
            
            obj.jerkAxis = subplot(4,1,4);
            title(obj.jerkAxis, 'Jerks');
            xlabel(obj.jerkAxis, 'Time (s)');
            ylabel(obj.jerkAxis, 'Jerk (m/s^3)');
            grid(obj.jerkAxis, 'on');
            hold(obj.jerkAxis, 'on');
        end
        
        function initializeVideoWriter(obj)
            % Create video writer if save_video is enabled
            [path, ~, ~] = fileparts(obj.config.visualization.video_filename);
            if ~exist(path, 'dir')
                mkdir(path);
            end
            
            obj.videoWriter = VideoWriter(obj.config.visualization.video_filename, 'MPEG-4');
            obj.videoWriter.FrameRate = obj.config.simulation.frame_rate;
            open(obj.videoWriter);
        end
    end
end