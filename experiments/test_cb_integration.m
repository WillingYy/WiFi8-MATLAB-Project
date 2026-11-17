function test_cb_integration()
% Run after adding this folder to MATLAB path.
fprintf('=== C+B integration tests ===\n');
cfg = default_config();
graph.adjMatrix = [0 1 0;1 0 1;0 1 0];
s = struct('t',0,'queueLen',[10 2 5], 'headWait',[0 0 0], 'rrPointer',1,'tiePointer',1);
assert(isequal(schedule_rr(s,graph,cfg),[1 3]));
assert(isequal(schedule_queue(s,graph,cfg),[1 3]));
% Explicitly exercise rotating tie-break and rotating RR priority.
s.queueLen = [3 3 3]; graph.adjMatrix=ones(3)-eye(3);
for k=1:3
    s.rrPointer=k; s.tiePointer=k;
    assert(isequal(schedule_rr(s,graph,cfg),k));
    assert(isequal(schedule_queue(s,graph,cfg),k));
end
% Verify all 8 graphs and 64 queue combinations.
for mask=0:7
    e=bitget(mask,1:3); g=zeros(3);g(1,2)=e(1);g(1,3)=e(2);g(2,3)=e(3);g=g+g';graph.adjMatrix=g;
    for x=0:3, for y=0:3, for z=0:3
        s.queueLen=[x y z];s.rrPointer=2;s.tiePointer=3;
        for pol=1:2
            if pol==1, a=schedule_rr(s,graph,cfg); else, a=schedule_queue(s,graph,cfg); end
            assert(numel(a)<=cfg.maxConcurrentAPs);
            assert(numel(unique(a))==numel(a));
            assert(all(s.queueLen(a)>0));
            assert(is_independent_set(a,g));
            assert(isempty(a)==~any(s.queueLen>0));
        end
    end, end, end
end
fprintf('[PASS] C scheduler unit and graph tests\n');
arr=generate_arrivals(cfg);
for policy={'random','rr','queue'}
    cfg.policy=policy{1};
    r=simulate_network(cfg,arr);
    assert(r.conservation.balanced);
    if ~strcmp(cfg.policy,'random')
        assert(r.aggregate.ctrlAirtime>0);
        for j=1:numel(r.eventLog)
            assert(is_independent_set(r.eventLog(j).selected,graph_from_cfg(cfg)));
        end
    end
    fprintf('[PASS] %s: arrivals=%d, completions=%d, P95=%.4f, ctrl=%.4f\n', ...
        cfg.policy,r.conservation.arrivals,r.conservation.completions,r.aggregate.p95Delay,r.aggregate.ctrlAirtime);
end
fprintf('=== C+B integration checks passed ===\n');
end
function g=graph_from_cfg(cfg)
g=zeros(cfg.numAPs);
for k=1:size(cfg.graphEdges,1)
    a=cfg.graphEdges(k,1);b=cfg.graphEdges(k,2);g(a,b)=1;g(b,a)=1;
end
end
