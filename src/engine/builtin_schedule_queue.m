function selectedAPs = builtin_schedule_queue(state, graph, cfg)
% BUILTIN_SCHEDULE_QUEUE  Temporary queue-aware placeholder.
% B provides this only so the engine can be tested end-to-end.
% C must replace this with the official schedule_queue.m.
%
% Rule used here (placeholder):
%   - pick nonempty AP with longest queue;
%   - tie-break by oldest head wait, then lowest index;
%   - add compatible nonempty APs by queue length descending,
%     then head wait descending, then index;
%   - respect cfg.maxConcurrentAPs.

numAPs = numel(state.queueLen);

best = [];
bestQ = -1;
bestWait = -1;

for ap = 1:numAPs
    if state.queueLen(ap) == 0
        continue;
    end
    if state.queueLen(ap) > bestQ || ...
       (state.queueLen(ap) == bestQ && state.headWait(ap) > bestWait)
        best = ap;
        bestQ = state.queueLen(ap);
        bestWait = state.headWait(ap);
    end
end

if isempty(best)
    selectedAPs = [];
    return;
end

selectedAPs = best;

candidates = [];
for ap = 1:numAPs
    if ap == best || state.queueLen(ap) == 0
        continue;
    end
    candidates(end+1) = ap; %#ok<AGROW>
end

if ~isempty(candidates)
    keys = zeros(numel(candidates), 3);
    for k = 1:numel(candidates)
        ap = candidates(k);
        keys(k,:) = [-state.queueLen(ap), -state.headWait(ap), ap];
    end
    [~, order] = sortrows(keys);
    candidates = candidates(order);
end

for ap = candidates
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