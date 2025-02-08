function stackTrace = getStackTrace(ME)
    % Convert error stack to readable string
    stackTrace = sprintf('Error in %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    for i = 2:length(ME.stack)
        stackTrace = [stackTrace sprintf('Called from %s (line %d)\n', ...
            ME.stack(i).name, ME.stack(i).line)];
    end
end