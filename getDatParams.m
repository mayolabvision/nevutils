function dat = getDatParams(dat)
    for n = 1:length(dat)
        preTrial{n} = dat(n).text;
        variables = regexp(preTrial{n},';','split');
        params = struct();
        trialParams = {};
        for j = 1:length(variables)
            k = strfind(variables{j},'=');
            if k
                lhs = variables{j}(1:k-1);
                rhs = variables{j}(k+1:end);
                if strcmp(lhs,'taskBoundary')
                    % end of this task's dump - stash it and start the next one
                    trialParams{end+1} = params; %#ok<AGROW>
                    params = struct();
                    continue;
                end
                try
                    eval(['params.' lhs '=[' rhs '];']);
                catch
                    eval(['params.' lhs '=''' rhs ''';']);
                end
            end
        end
        % Flush the final (or only) params block. A dump doesn't always end
        % with an explicit taskBoundary marker (e.g. combined-task ex files
        % like 'dirmemAndRFmap' that only ever write one params block).
        if ~isempty(fieldnames(params))
            trialParams{end+1} = params;
        end
        % Single-task dumps (no taskBoundary) yield exactly one params block --
        % keep those as a bare struct instead of a 1x1 cell. Combined-task
        % dumps with multiple taskBoundary-delimited blocks stay a cell array.
        if isscalar(trialParams)
            dat(n).params.trial = trialParams{1};
        else
            dat(n).params.trial = trialParams;
        end
    end
end