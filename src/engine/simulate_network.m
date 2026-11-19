function result = simulate_network(cfg, arrivalTrace)
% SIMULATE_NETWORK  Unified discrete-time engine for the Wi-Fi 8-inspired
% multi-AP coordination study.
%
%   result = simulate_network(cfg, arrivalTrace)
%
% Engine owns clock, arrivals, queues, service, statistics.
% Coordinated schedulers are called as read-only functions:
%   selectedAPs = schedule_rr(state, graph, cfg)
%   selectedAPs = schedule_queue(state, graph, cfg)
% If those files are not on the path, builtin placeholders are used.

numAPs = cfg.numAPs;

% Build adjacency matrix
adjMatrix = zeros(numAPs);
for e = 1:size(cfg.graphEdges, 1)
    i = cfg.graphEdges(e,1);
    j = cfg.graphEdges(e,2);
    adjMatrix(i,j) = 1;
    adjMatrix(j,i) = 1;
end

% Independent random stream for access/backoff
sAcc = RandStream('mt19937ar', 'Seed', cfg.seedAccess);

% State
state.t        = 0;
state.queueLen = zeros(1, numAPs);
state.headWait = zeros(1, numAPs);
state.backoff  = zeros(1, numAPs);
state.rrPointer = 1;
state.tiePointer = 1;

% Queues: Nx2 [arrivalTime, bits]
queues = cell(1, numAPs);
for ap = 1:numAPs
    queues{ap} = zeros(0, 2);
end

% Arrival tracking
nArrivals = zeros(1, numAPs);
for ap = 1:numAPs
    nArrivals(ap) = numel(arrivalTrace.times{ap});
end
nextIdx = ones(1, numAPs);

% Completion records
compArrival    = cell(1, numAPs);
compCompletion = cell(1, numAPs);
compBits       = cell(1, numAPs);
for ap = 1:numAPs
    compArrival{ap}    = [];
    compCompletion{ap} = [];
    compBits{ap}       = [];
end

% Event log
eventLog = struct('t', {}, 'policy', {}, 'attempted', {}, ...
                  'selected', {}, 'outcome', {});

% Counters
ctrlAirtime   = 0;
failedAirtime = 0;
numAttempts   = 0;
numConflicts  = 0;

% Process arrivals at t=0
[queues, nextIdx] = local_process_arrivals(queues, arrivalTrace, nextIdx, 0);
state = local_update_state(state, queues, numAPs);

% Main loop
policy = cfg.policy;
maxSteps = ceil(cfg.Tsim / max(cfg.Tdata, cfg.Tslot)) * 20 + 1000;
stepCount = 0;

while state.t < cfg.Tsim - 1e-12
    stepCount = stepCount + 1;
    if stepCount > maxSteps
        error('simulate_network:maxSteps', ...
              'Exceeded maximum steps. Check Tsim, Tdata, Tslot, Tctrl.');
    end

    if strcmp(policy, 'random')
        % ---------------- Random-access slot ----------------
        % Decrement backoff
        for ap = 1:numAPs
            if state.backoff(ap) > 0
                state.backoff(ap) = state.backoff(ap) - 1;
            end
        end

        % Attempt set
        attemptAPs = [];
        for ap = 1:numAPs
            if state.queueLen(ap) > 0 && state.backoff(ap) == 0
                if rand(sAcc) < cfg.attemptProb
                    attemptAPs(end+1) = ap; %#ok<AGROW>
                end
            end
        end

        % Conflict resolution
        successAPs = [];
        failAPs    = [];
        for i = 1:numel(attemptAPs)
            ap = attemptAPs(i);
            hasConflict = false;
            for j = 1:numel(attemptAPs)
                if i ~= j && adjMatrix(ap, attemptAPs(j))
                    hasConflict = true;
                    break;
                end
            end
            if hasConflict
                failAPs(end+1) = ap; %#ok<AGROW>
            else
                successAPs(end+1) = ap; %#ok<AGROW>
            end
        end

        if ~isempty(attemptAPs)
            numAttempts = numAttempts + 1;
        end
        if ~isempty(failAPs)
            numConflicts = numConflicts + numel(failAPs);
        end

        % Advance time
        t_before = state.t;
        t_next = min(state.t + cfg.Tslot, cfg.Tsim);
        [queues, nextIdx] = local_process_arrivals(queues, arrivalTrace, nextIdx, t_next);
        state.t = t_next;

        % Failed transmission airtime inside measurement window
        if ~isempty(failAPs) && t_before >= cfg.Twarmup && t_before < cfg.Tsim
            failedAirtime = failedAirtime + (t_next - t_before);
        end

        % Remove successful packets
        for ap = successAPs
            if size(queues{ap},1) > 0
                pkt = queues{ap}(1,:);
                queues{ap}(1,:) = [];
                compArrival{ap}(end+1)    = pkt(1); %#ok<AGROW>
                compCompletion{ap}(end+1) = state.t; %#ok<AGROW>
                compBits{ap}(end+1)       = pkt(2); %#ok<AGROW>
                if size(queues{ap},1) == 0
                    state.backoff(ap) = 0;
                end
            end
        end

        % Set new backoff for failed APs
        for ap = failAPs
            state.backoff(ap) = randi(sAcc, [1, cfg.backoffMax]);
        end

        state = local_update_state(state, queues, numAPs);

        if ~isempty(attemptAPs)
            ev.t         = state.t;
            ev.policy    = policy;
            ev.attempted = attemptAPs;
            ev.selected  = successAPs;
            ev.outcome   = 'random_slot';
            if isempty(eventLog)
                eventLog = ev;
            else
                eventLog(end+1) = ev; %#ok<AGROW>
            end
        end

    else
        % ---------------- Coordinated slot ----------------
        anyNonempty = false;
        for ap = 1:numAPs
            if size(queues{ap},1) > 0
                anyNonempty = true;
                break;
            end
        end

        if ~anyNonempty
            t_next = min(state.t + cfg.Tslot, cfg.Tsim);
            [queues, nextIdx] = local_process_arrivals(queues, arrivalTrace, nextIdx, t_next);
            state.t = t_next;
            state = local_update_state(state, queues, numAPs);
            continue;
        end

        % Snapshot and control interval
        t_before = state.t;
        if strcmp(cfg.snapshotTime, 'before_ctrl')
            snapshot = local_build_snapshot(state, queues, numAPs);
            t_next = min(state.t + cfg.Tctrl, cfg.Tsim);
            [queues, nextIdx] = local_process_arrivals(queues, arrivalTrace, nextIdx, t_next);
            state.t = t_next;
        else
            t_next = min(state.t + cfg.Tctrl, cfg.Tsim);
            [queues, nextIdx] = local_process_arrivals(queues, arrivalTrace, nextIdx, t_next);
            state.t = t_next;
            snapshot = local_build_snapshot(state, queues, numAPs);
        end

        if t_before >= cfg.Twarmup && t_before < cfg.Tsim
            ctrlAirtime = ctrlAirtime + (t_next - t_before);
        end

        % Scheduler call
        graph.adjMatrix = adjMatrix;
        if strcmp(policy, 'rr')
            if exist('schedule_rr', 'file') == 2
                selectedAPs = schedule_rr(snapshot, graph, cfg);
            else
                selectedAPs = builtin_schedule_rr(snapshot, graph, cfg);
            end
        elseif strcmp(policy, 'queue')
            if exist('schedule_queue', 'file') == 2
                selectedAPs = schedule_queue(snapshot, graph, cfg);
            else
                selectedAPs = builtin_schedule_queue(snapshot, graph, cfg);
            end
        else
            error('simulate_network:policy', 'Unknown policy: %s', policy);
        end

        % Persist scheduling fairness state (the scheduler itself is read-only).
        if ~isempty(selectedAPs)
            if strcmp(policy, 'rr')
                state.rrPointer = mod(selectedAPs(1), numAPs) + 1;
            elseif strcmp(policy, 'queue')
                state.tiePointer = mod(selectedAPs(1), numAPs) + 1;
            end
        end

        % Validate independent set
        if ~is_independent_set(selectedAPs, adjMatrix)
            error('simulate_network:nonIndependent', ...
                  'Scheduler returned non-independent set: [%s]', ...
                  num2str(selectedAPs));
        end

        % Cap concurrency
        if numel(selectedAPs) > cfg.maxConcurrentAPs
            selectedAPs = selectedAPs(1:cfg.maxConcurrentAPs);
        end

        % Advance Tdata
        t_next = min(state.t + cfg.Tdata, cfg.Tsim);
        [queues, nextIdx] = local_process_arrivals(queues, arrivalTrace, nextIdx, t_next);
        state.t = t_next;

        % Remove packets
        for ap = selectedAPs
            if size(queues{ap},1) > 0
                pkt = queues{ap}(1,:);
                queues{ap}(1,:) = [];
                compArrival{ap}(end+1)    = pkt(1); %#ok<AGROW>
                compCompletion{ap}(end+1) = state.t; %#ok<AGROW>
                compBits{ap}(end+1)       = pkt(2); %#ok<AGROW>
                if size(queues{ap},1) == 0
                    state.backoff(ap) = 0;
                end
            end
        end

        state = local_update_state(state, queues, numAPs);

        ev.t         = state.t;
        ev.policy    = policy;
        ev.attempted = selectedAPs;
        ev.selected  = selectedAPs;
        ev.outcome   = 'coord_slot';
        if isempty(eventLog)
            eventLog = ev;
        else
            eventLog(end+1) = ev; %#ok<AGROW>
        end
    end
end

% ---------------- Build result ----------------
result = local_build_result(cfg, compArrival, compCompletion, compBits, ...
    queues, nArrivals, eventLog, numAPs, ctrlAirtime, failedAirtime, ...
    numAttempts, numConflicts);
end

% =====================================================================
function [queues, nextIdx] = local_process_arrivals(queues, arrivalTrace, nextIdx, t_until)
% Add all packets with arrival time <= t_until to the queues.
for ap = 1:numel(queues)
    times = arrivalTrace.times{ap};
    bits  = arrivalTrace.bits{ap};
    while nextIdx(ap) <= numel(times) && times(nextIdx(ap)) <= t_until + 1e-12
        queues{ap}(end+1,:) = [times(nextIdx(ap)), bits(nextIdx(ap))]; %#ok<AGROW>
        nextIdx(ap) = nextIdx(ap) + 1;
    end
end
end

% =====================================================================
function state = local_update_state(state, queues, numAPs)
for ap = 1:numAPs
    n = size(queues{ap}, 1);
    state.queueLen(ap) = n;
    if n > 0
        state.headWait(ap) = state.t - queues{ap}(1,1);
    else
        state.headWait(ap) = 0;
    end
end
end

% =====================================================================
function snapshot = local_build_snapshot(state, queues, numAPs)
snapshot.t        = state.t;
snapshot.rrPointer = state.rrPointer;
snapshot.tiePointer = state.tiePointer;
snapshot.queueLen = zeros(1, numAPs);
snapshot.headWait = zeros(1, numAPs);
for ap = 1:numAPs
    n = size(queues{ap}, 1);
    snapshot.queueLen(ap) = n;
    if n > 0
        snapshot.headWait(ap) = state.t - queues{ap}(1,1);
    end
end
end

% =====================================================================
function result = local_build_result(cfg, compArrival, compCompletion, compBits, ...
    queues, nArrivals, eventLog, numAPs, ctrlAirtime, failedAirtime, ...
    numAttempts, numConflicts)

T  = cfg.Tsim;
Tw = cfg.Twarmup;
winLen = max(T - Tw, eps);

% Aggregate completions inside measurement window
allDelay = [];
allBits  = [];
for ap = 1:numAPs
    cc = compCompletion{ap};
    ca = compArrival{ap};
    cb = compBits{ap};
    for k = 1:numel(cc)
        if cc(k) >= Tw && cc(k) <= T
            allDelay(end+1) = cc(k) - ca(k); %#ok<AGROW>
            allBits(end+1)  = cb(k);         %#ok<AGROW>
        end
    end
end

% Per-AP stats
perAP = struct();
for ap = 1:numAPs
    cc = compCompletion{ap};
    ca = compArrival{ap};
    cb = compBits{ap};
    delays  = [];
    bitsSum = 0;
    for k = 1:numel(cc)
        if cc(k) >= Tw && cc(k) <= T
            delays(end+1) = cc(k) - ca(k); %#ok<AGROW>
            bitsSum = bitsSum + cb(k);
        end
    end
    perAP(ap).completedPackets = numel(delays);
    perAP(ap).p95Delay         = my_quantile(delays, 0.95);
    perAP(ap).goodput          = bitsSum / winLen;
    perAP(ap).backlogEnd       = size(queues{ap}, 1);
    perAP(ap).unfinished       = size(queues{ap}, 1);
end

% Aggregate
result.meta.cfg              = cfg;
result.meta.matlabVersion    = version;
result.meta.seedArrival      = cfg.seedArrival;
result.meta.seedAccess       = cfg.seedAccess;
result.meta.quantileMethod   = cfg.quantileMethod;

result.completions.arrivalTime    = compArrival;
result.completions.completionTime = compCompletion;
result.completions.bits           = compBits;

result.perAP = perAP;

result.aggregate.p95Delay     = my_quantile(allDelay, 0.95);
result.aggregate.goodput      = sum(allBits) / winLen;
result.aggregate.ctrlAirtime   = ctrlAirtime / winLen;
result.aggregate.failedAirtime = failedAirtime / winLen;
result.aggregate.numAttempts   = numAttempts;
result.aggregate.numConflicts  = numConflicts;

result.eventLog = eventLog;

% Conservation
totalArrived = sum(nArrivals);
totalCompleted = 0;
totalRemaining = 0;
for ap = 1:numAPs
    totalCompleted = totalCompleted + numel(compCompletion{ap});
    totalRemaining = totalRemaining + size(queues{ap}, 1);
end
result.conservation.arrivals    = totalArrived;
result.conservation.completions = totalCompleted;
result.conservation.unfinished  = totalRemaining;
result.conservation.dropped     = 0;
result.conservation.balanced    = (totalArrived == totalCompleted + totalRemaining);
end
