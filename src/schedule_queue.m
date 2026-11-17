function selectedAPs = schedule_queue(state, graph, cfg)
% Official C longest-queue-first with rotating tie-break.
% Read-only; the engine updates the tie pointer after each decision.
q = state.queueLen(:)';
N = numel(q);
assert(isequal(size(graph.adjMatrix),[N N]), 'Invalid adjacency matrix');
assert(isfield(state,'tiePointer'), 'Engine must supply state.tiePointer');
selectedAPs = [];
if ~any(q>0), return; end
start = state.tiePointer;
assert(isscalar(start) && start>=1 && start<=N && start==floor(start));
order = mod((start-1)+(0:N-1),N)+1;
maxQ = max(q);
head = order(find(q(order)==maxQ,1,'first'));
selectedAPs = head;
for ap = order
    if numel(selectedAPs)>=cfg.maxConcurrentAPs, break; end
    if q(ap)>0 && ~ismember(ap,selectedAPs) && all(graph.adjMatrix(ap,selectedAPs)==0)
        selectedAPs(end+1)=ap; %#ok<AGROW>
    end
end
end
