function results = verifyToolbox()
% VERIFYTOOLBOX Simple verification of Deep Learning Toolbox installation
%
% Author: zplotzke
% Last Modified: 2025-02-19 17:34:45 UTC
% Version: 1.0.0

% Initialize results
results = struct();

% Check for Deep Learning Toolbox
v = ver;
results.installed_toolboxes = {v.Name};

% Specifically check Deep Learning Toolbox
hasDeep = any(strcmp('Deep Learning Toolbox', {v.Name}));
if hasDeep
    deepInfo = ver('deep');
    results.status = 'installed';
    results.version = deepInfo.Version;
    results.release = deepInfo.Release;
else
    results.status = 'not_installed';
    results.required = 'Deep Learning Toolbox is required for LSTM network validation';
end

end