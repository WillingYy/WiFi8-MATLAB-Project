function selectedAPs = schedule_rr(state, graph, cfg)
% Official C round-robin scheduler for B interface v1.1.
% Read-only; the engine updates the rotating pointer after each decision.
q = state.queueLen(:)';
N = numel(q);
assert(isequal(size(graph.adjMatrix),[N N]), 'Invalid adjacency matrix');
assert(isfield(state,'rrPointer'), 'Engine must supply state.rrPointer');
selectedAPs = [];
if ~any(q>0), return; end
start = state.rrPointer;
assert(isscalar(start) && start>=1 && start<=N && start==floor(start));
order = mod((start-1)+(0:N-1),N)+1;
head = order(find(q(order)>0,1,'first'));
selectedAPs = head;
for ap = order
    if numel(selectedAPs)>=cfg.maxConcurrentAPs, break; end
    if q(ap)>0 && ~ismember(ap,selectedAPs) && all(graph.adjMatrix(ap,selectedAPs)==0)
        selectedAPs(end+1)=ap; %#ok<AGROW>
    end
end
end
