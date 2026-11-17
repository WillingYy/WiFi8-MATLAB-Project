function run_demo()
% RUN_DEMO  One-command demo: run all three policies on the same arrival trace.

fprintf('=== WiFi8 MATLAB Demo ===\n');
fprintf('MATLAB version: %s\n\n', version);

cfg = default_config();
arrivalTrace = generate_arrivals(cfg);

fprintf('Arrivals generated: ');
for ap = 1:cfg.numAPs
    fprintf('AP%d=%d ', ap, numel(arrivalTrace.times{ap}));
end
fprintf('\n\n');

policies = {'random', 'rr', 'queue'};

for p = 1:numel(policies)
    cfg.policy = policies{p};
    fprintf('--- Policy: %s ---\n', cfg.policy);
    r = simulate_network(cfg, arrivalTrace);

    fprintf('  Conservation: arrivals=%d completions=%d unfinished=%d dropped=%d balanced=%d\n', ...
        r.conservation.arrivals, r.conservation.completions, ...
        r.conservation.unfinished, r.conservation.dropped, r.conservation.balanced);
    fprintf('  Pooled P95 delay = %.4f\n', r.aggregate.p95Delay);
    fprintf('  Pooled goodput   = %.4f bits/time\n', r.aggregate.goodput);
    fprintf('  ctrlAirtime      = %.4f\n', r.aggregate.ctrlAirtime);
    fprintf('  failedAirtime    = %.4f\n', r.aggregate.failedAirtime);
    fprintf('  numAttempts      = %d\n', r.aggregate.numAttempts);
    fprintf('  numConflicts     = %d\n', r.aggregate.numConflicts);

    for ap = 1:cfg.numAPs
        fprintf('  AP%d: completed=%d P95=%.4f goodput=%.4f backlogEnd=%d unfinished=%d\n', ...
            ap, r.perAP(ap).completedPackets, r.perAP(ap).p95Delay, ...
            r.perAP(ap).goodput, r.perAP(ap).backlogEnd, r.perAP(ap).unfinished);
    end
    fprintf('\n');
end

fprintf('=== Demo complete ===\n');
fprintf('To run minimal K3 checks: validate_engine\n');
end
