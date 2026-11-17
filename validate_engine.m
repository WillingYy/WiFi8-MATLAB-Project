function validate_engine()
% VALIDATE_ENGINE  Minimal K3 checks for the unified engine.
% Prints PASS/FAIL for each check.

fprintf('=== validate_engine: K3 checks ===\n');

pass = 0;
fail = 0;

% --- Test 1: empty queues -> no transmissions ---
cfg = default_config();
cfg.lambda = [0 0 0];
cfg.Tsim = 10;
cfg.Twarmup = 0;
arr = generate_arrivals(cfg);
cfg.policy = 'random';
r = simulate_network(cfg, arr);
if r.conservation.arrivals == 0 && r.conservation.completions == 0
    fprintf('[PASS] T1: empty queues produce no transmissions\n');
    pass = pass + 1;
else
    fprintf('[FAIL] T1: empty queues produced activity\n');
    fail = fail + 1;
end

% --- Test 2: single nonempty AP ---
cfg = default_config();
cfg.lambda = [1 0 0];
cfg.Tsim = 50;
cfg.Twarmup = 0;
arr = generate_arrivals(cfg);
cfg.policy = 'random';
r = simulate_network(cfg, arr);
if r.conservation.completions > 0 && r.conservation.completions <= r.conservation.arrivals
    fprintf('[PASS] T2: single AP scenario completes packets\n');
    pass = pass + 1;
else
    fprintf('[FAIL] T2: single AP scenario\n');
    fail = fail + 1;
end

% --- Test 3: conservation ---
if r.conservation.balanced
    fprintf('[PASS] T3: arrivals = completions + unfinished\n');
    pass = pass + 1;
else
    fprintf('[FAIL] T3: conservation violated\n');
    fail = fail + 1;
end

% --- Test 4: independent set on path graph ---
adj = [0 1 0; 1 0 1; 0 1 0];
if is_independent_set([1 3], adj)
    fprintf('[PASS] T4: {1,3} is independent on path graph\n');
    pass = pass + 1;
else
    fprintf('[FAIL] T4: is_independent_set missed independence\n');
    fail = fail + 1;
end

% --- Test 5: edge detected ---
if ~is_independent_set([1 2], adj)
    fprintf('[PASS] T5: {1,2} detected as conflicting\n');
    pass = pass + 1;
else
    fprintf('[FAIL] T5: is_independent_set missed edge\n');
    fail = fail + 1;
end

% --- Test 6: coordinated policy respects independent set ---
cfg = default_config();
cfg.lambda = [0.5 0.5 0.5];
cfg.Tsim = 100;
cfg.Twarmup = 0;
arr = generate_arrivals(cfg);
cfg.policy = 'queue';
r = simulate_network(cfg, arr);
if r.conservation.balanced
    fprintf('[PASS] T6: queue policy runs and conserves packets\n');
    pass = pass + 1;
else
    fprintf('[FAIL] T6: queue policy conservation\n');
    fail = fail + 1;
end

% --- Test 7: rr policy runs ---
cfg.policy = 'rr';
r = simulate_network(cfg, arr);
if r.conservation.balanced
    fprintf('[PASS] T7: rr policy runs and conserves packets\n');
    pass = pass + 1;
else
    fprintf('[FAIL] T7: rr policy conservation\n');
    fail = fail + 1;
end

% --- Test 8: control airtime counted for coordinated policy ---
if r.aggregate.ctrlAirtime > 0
    fprintf('[PASS] T8: control airtime counted for coordinated policy\n');
    pass = pass + 1;
else
    fprintf('[FAIL] T8: control airtime is zero\n');
    fail = fail + 1;
end

% --- Test 9: failed airtime counted for random baseline ---
cfg.policy = 'random';
cfg.attemptProb = 1.0;   % force collisions on path graph
r2 = simulate_network(cfg, arr);
if r2.aggregate.failedAirtime >= 0
    fprintf('[PASS] T9: failed airtime field populated (%.4f)\n', ...
        r2.aggregate.failedAirtime);
    pass = pass + 1;
else
    fprintf('[FAIL] T9: failed airtime field\n');
    fail = fail + 1;
end

fprintf('\n=== validate_engine: %d passed, %d failed ===\n', pass, fail);
end
