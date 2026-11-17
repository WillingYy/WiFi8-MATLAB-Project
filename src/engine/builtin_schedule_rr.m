function selectedAPs = builtin_schedule_rr(state, graph, cfg)
% BUILTIN_SCHEDULE_RR  Temporary round-robin placeholder.
% B provides this only so the engine can be tested end-to-end.
% C must replace this with the official schedule_rr.m.
%
% Rule used here (placeholder):
%   - pick the first nonempty AP in index order;
%   - add compatible nonempty APs in index order;
%   - respect cfg.maxConcurrentAPs.

numAPs = numel(state.queueLen);

first = [];
for ap = 1:numAPs
    if state.queueLen(ap) > 0
        first = ap;
        break;
    end
end

if isempty(first)
    selectedAPs = [];
    return;
end

selectedAPs = first;

for ap = 1:numAPs
    if ap == first
        continue;
    end
    if state.queueLen(ap) == 0
        continue;
    end

    ok = true;
    for s = selectedAPs
        if graph.adjMatrix(ap, s)
            ok = false;
            break;
        end
    end

    if ok
        selectedAPs(end+1) = ap; %#ok<AGROW>
        if numel(selectedAPs) >= cfg.maxConcurrentAPs
            break;
        end
    end
end
end