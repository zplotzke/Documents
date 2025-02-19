classdef Sonificator < handle
    % SONIFICATOR Converts safety warnings into audio signals
    %
    % Author: zplotzke
    % Last Modified: 2025-02-19 15:07:20 UTC
    % Version: 1.0.0

    properties (Access = private)
        config
        logger
        warningTones     % Map of warning types to frequencies
        audioPlayer      % Audio player object
        isEnabled       % Sonification enabled flag
        lastSoundTime   % Time of last sound played
    end

    methods
        function obj = Sonificator()
            obj.config = config.getConfig();
            obj.logger = utils.Logger.getLogger('Sonificator');

            % Initialize warning tones (Hz)
            obj.warningTones = containers.Map();
            obj.warningTones('COLLISION') = 880;    % A5 - Highest priority
            obj.warningTones('EMERGENCY_BRAKE') = 784; % G5
            obj.warningTones('DISTANCE') = 659.25;  % E5
            obj.warningTones('SPEED') = 523.25;     % C5 - Lowest priority

            obj.isEnabled = true;
            obj.lastSoundTime = 0;

            obj.logger.info('Sonificator initialized');
        end

        function sonifyWarning(obj, warningType, severity)
            if ~obj.isEnabled || ~obj.warningTones.isKey(warningType)
                return;
            end

            % Ensure minimum time between sounds (250ms)
            currentTime = now * 86400; % Convert to seconds
            if (currentTime - obj.lastSoundTime) < 0.25
                return;
            end

            % Generate warning tone
            fs = 44100;  % Sample rate
            duration = 0.3;  % Base tone duration
            t = 0:1/fs:duration;

            % Get base frequency
            baseFreq = obj.warningTones(warningType);

            % Modify amplitude based on severity (0.2-1.0)
            amplitude = 0.2 + (0.8 * severity);

            % Generate tone with envelope
            envelope = sin(pi*t/duration);  % Smooth envelope

            % Add harmonics for richer sound
            signal = amplitude * envelope .* (...
                0.6 * sin(2*pi*baseFreq*t) + ...    % Fundamental
                0.3 * sin(4*pi*baseFreq*t) + ...    % 1st harmonic
                0.1 * sin(6*pi*baseFreq*t));        % 2nd harmonic

            % Add slight frequency modulation for urgency in high severity cases
            if severity > 0.7
                modFreq = 15; % 15 Hz modulation
                modDepth = 0.1;
                signal = signal .* (1 + modDepth * sin(2*pi*modFreq*t));
            end

            % Play sound
            sound(signal, fs);
            obj.lastSoundTime = currentTime;

            obj.logger.debug('Playing %s warning tone (severity: %.2f)', ...
                warningType, severity);
        end

        function enable(obj)
            obj.isEnabled = true;
            obj.logger.info('Sonification enabled');
        end

        function disable(obj)
            obj.isEnabled = false;
            obj.logger.info('Sonification disabled');
        end

        function isEnabled = getEnabled(obj)
            isEnabled = obj.isEnabled;
        end
    end
end