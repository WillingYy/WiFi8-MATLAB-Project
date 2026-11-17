clear

% Configure replications, offered loads, and control-to-data time ratios.
nRep = 20;
loads = [0.15 0.30 0.45];
ctrlRatios = [0 0.1 0.25 0.5 1 1.5 2 3 4];
policies = ["random", "rr", "queue"];

% Create a separate output directory for this batch.
batchID = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile('results', "D_overhead_" + batchID);
mkdir(outDir)

% Configure the shared simulation engine.
base = default_config();
base.Tsim = 10000;
base.Twarmup = 1000;
base.Tdata = 1;
base.Tslot = 1;
base.graphEdges = [1 2; 2 3];
base.maxConcurrentAPs = 2;
base.snapshotTime = 'before_ctrl';

% Define separate arrival and access seeds.
seedArrival = 10000 + (1:nRep);
seedAccess = 20000 + (1:nRep);
checkpoint = linspace(base.Twarmup, base.Tsim, 5);

% Save all settings required to reproduce the batch.
save(fullfile(outDir, 'batch_config.mat'), ...
    'base', 'nRep', 'loads', 'ctrlRatios', 'policies', ...
    'seedArrival', 'seedAccess', 'checkpoint')

% Save the mapping between scenario IDs and experimental settings.
manifestRows = cell(0, 4);
for k = 1:numel(loads)
    for j = 1:numel(ctrlRatios)
        scenarioID = (k-1)*numel(ctrlRatios) + j;
        manifestRows(end+1,:) = { ...
            scenarioID, k, loads(k), ctrlRatios(j)};
    end
end

manifest = cell2table(manifestRows, 'VariableNames', ...
    {'ScenarioID','LoadID','TotalLambda','CtrlRatio'});
writetable(manifest, fullfile(outDir, 'scenario_manifest.csv'));

% Define one metrics row per AP and one network-level row per run.
rowNames = {'ScenarioID','LoadID','TotalLambda','CtrlRatio', ...
    'Repeat','SeedArrival','SeedAccess','Policy','AP', ...
    'MeasureTime','NArrived','NCompletedTotal','NCompletedWindow', ...
    'P95','Goodput','CtrlAirtime','Dropped','Unfinished', ...
    'OutstandingAtWarmup','OutstandingAtMidpoint'};

rows = cell(0, numel(rowNames));
runCount = 0;

for k = 1:numel(loads)
    for rep = 1:nRep
        cfg = base;
        cfg.lambda = loads(k) * [1 1 1] / 3;
        cfg.seedArrival = seedArrival(rep);
        cfg.seedAccess = seedAccess(rep);

        % Reuse this arrival trace across all policies and overhead settings.
        trace = generate_arrivals(cfg);

        traceName = sprintf('trace_load_%02d_rep_%02d.mat', k, rep);
        save(fullfile(outDir, traceName), 'trace', 'cfg')

        % Run random access once because it does not use control intervals.
        cfg.policy = 'random';
        cfg.Tctrl = 0;
        r = simulate_network(cfg, trace);

        assert(r.conservation.balanced)
        outstanding = compute_outstanding(trace, r, checkpoint);
        assert(all(outstanding(:,end)' == [r.perAP.unfinished]))

        % CtrlRatio=NaN identifies a reusable random-access baseline.
        baselineRows = make_metric_rows( ...
            cfg, trace, r, outstanding, 0, k, loads(k), NaN, rep);
        rows = [rows; baselineRows];

        name = sprintf('run_load_%02d_rep_%02d_random.mat', k, rep);
        save(fullfile(outDir, name), ...
            'cfg', 'trace', 'r', 'checkpoint', 'outstanding')
        runCount = runCount + 1;

        % Run both coordinated policies at every overhead setting.
        for j = 1:numel(ctrlRatios)
            ratio = ctrlRatios(j);
            scenarioID = (k-1)*numel(ctrlRatios) + j;
            cfg.Tctrl = ratio * cfg.Tdata;

            for p = 2:numel(policies)
                cfg.policy = char(policies(p));
                r = simulate_network(cfg, trace);

                assert(r.conservation.balanced, ...
                    'Conservation failed: load=%d, ratio=%g, rep=%d, policy=%s', ...
                    k, ratio, rep, cfg.policy)

                outstanding = compute_outstanding(trace, r, checkpoint);
                assert(all(outstanding(:,end)' == [r.perAP.unfinished]))

                newRows = make_metric_rows( ...
                    cfg, trace, r, outstanding, ...
                    scenarioID, k, loads(k), ratio, rep);
                rows = [rows; newRows];

                name = sprintf( ...
                    'run_load_%02d_ctrl_%02d_rep_%02d_%s.mat', ...
                    k, j, rep, cfg.policy);

                save(fullfile(outDir, name), ...
                    'cfg', 'trace', 'r', 'checkpoint', 'outstanding')
                runCount = runCount + 1;
            end
        end

        % Save accumulated metrics after each completed seed pair.
        metricsTable = cell2table(rows, 'VariableNames', rowNames);
        writetable(metricsTable, fullfile(outDir, 'run_metrics.csv'));

        fprintf('Completed load %d/%d, seed pair %d/%d\n', ...
            k, numel(loads), rep, nRep)
    end
end

% Validate output counts and packet conservation.
expectedRuns = numel(loads)*nRep*(1 + 2*numel(ctrlRatios));
expectedRows = expectedRuns*(base.numAPs + 1);

G = metricsTable(metricsTable.AP == 0, :);
runFiles = dir(fullfile(outDir, 'run_load_*.mat'));

assert(runCount == expectedRuns)
assert(numel(runFiles) == expectedRuns)
assert(height(metricsTable) == expectedRows)
assert(height(G) == expectedRuns)
assert(all(G.NArrived == ...
    G.NCompletedTotal + G.Unfinished + G.Dropped))

% Verify that every overhead setting used the same arrivals within a load.
for k = 1:numel(loads)
    for rep = 1:nRep
        S = G(G.LoadID == k & G.Repeat == rep, :);
        assert(height(S) == 1 + 2*numel(ctrlRatios))
        assert(all(S.NArrived == S.NArrived(1)))
    end
end

fprintf('\nBatch checks passed: %d runs and %d metric rows.\n', ...
    expectedRuns, expectedRows);
fprintf('Batch outputs: %s\n', outDir);


function outstanding = compute_outstanding(trace, r, checkpoint)
% Count arrived packets that have not completed at each checkpoint.
    nAP = numel(trace.times);
    outstanding = zeros(nAP, numel(checkpoint));

    for ap = 1:nAP
        arrivals = trace.times{ap};
        completions = r.completions.completionTime{ap};

        outstanding(ap,:) = arrayfun( ...
            @(t) nnz(arrivals <= t) - nnz(completions <= t), ...
            checkpoint);
    end
end


function rows = make_metric_rows( ...
    cfg, trace, r, outstanding, scenarioID, loadID, totalLambda, ratio, rep)
% Build AP-level and network-level metrics using the engine outputs.
    rows = cell(cfg.numAPs+1, 20);
    measureTime = cfg.Tsim - cfg.Twarmup;

    for ap = 1:cfg.numAPs
        m = r.perAP(ap);

        rows(ap,:) = { ...
            scenarioID, loadID, totalLambda, ratio, ...
            rep, cfg.seedArrival, cfg.seedAccess, string(cfg.policy), ...
            ap, measureTime, numel(trace.times{ap}), ...
            numel(r.completions.completionTime{ap}), ...
            m.completedPackets, m.p95Delay, m.goodput, ...
            NaN, NaN, m.unfinished, ...
            outstanding(ap,1), outstanding(ap,3)};
    end

    c = r.conservation;
    g = r.aggregate;

    rows(end,:) = { ...
        scenarioID, loadID, totalLambda, ratio, ...
        rep, cfg.seedArrival, cfg.seedAccess, string(cfg.policy), ...
        0, measureTime, c.arrivals, c.completions, ...
        sum([r.perAP.completedPackets]), ...
        g.p95Delay, g.goodput, g.ctrlAirtime, c.dropped, ...
        c.unfinished, sum(outstanding(:,1)), ...
        sum(outstanding(:,3))};
end