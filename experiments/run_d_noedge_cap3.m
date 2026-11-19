clear

% Configure independent replications and policies.
nRep = 20;
totalLambda = 0.30;
policies = ["random", "rr", "queue"];

% Create a separate output directory for this batch.
batchID = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile('results', "D_noedge_cap3_" + batchID);
mkdir(outDir)

% Configure the no-edge graph with a coordinated concurrency cap of three.
base = default_config();
base.Tsim = 10000;
base.Twarmup = 1000;
base.lambda = totalLambda * [1 1 1] / 3;
base.graphEdges = zeros(0,2);
base.maxConcurrentAPs = 3;
base.snapshotTime = 'before_ctrl';
base.Tctrl = 0.10 * base.Tdata;

% Retain graph metadata for compatibility with the graph batch format.
graphList = {base.graphEdges};
graphNames = "No edges";
edgeCounts = 0;
nScenarios = numel(graphList);

% Define checkpoints and separate arrival and access seeds.
checkpoint = linspace(base.Twarmup, base.Tsim, 5);
seedArrival = 10000 + (1:nRep);
seedAccess = 20000 + (1:nRep);

% Save the scenario mapping.
scenarioTable = table( ...
    1, 0, "No edges", "[]", totalLambda, base.maxConcurrentAPs, ...
    'VariableNames', {'LoadID','EdgeCount','GraphName','GraphEdges', ...
    'TotalLambda','MaxConcurrentAPs'});

writetable(scenarioTable, fullfile(outDir, 'scenario_manifest.csv'));

% Save all batch settings needed for reproduction.
save(fullfile(outDir, 'batch_config.mat'), ...
    'base', 'nRep', 'totalLambda', 'policies', ...
    'graphList', 'graphNames', 'edgeCounts', 'nScenarios', ...
    'checkpoint', 'seedArrival', 'seedAccess', 'scenarioTable')

disp(scenarioTable)

% Define the output table columns.
rows = cell(0, 18);
rowNames = {'LoadID','TotalLambda','Repeat','SeedArrival','SeedAccess', ...
    'Policy','AP','MeasureTime','NArrived','NCompletedTotal', ...
    'NCompletedWindow','P95','Goodput','CtrlAirtime','Dropped', ...
    'Unfinished','OutstandingAtWarmup','OutstandingAtMidpoint'};

% Generate one arrival trace per replication and share it across policies.
for rep = 1:nRep
    cfg = base;
    cfg.seedArrival = seedArrival(rep);
    cfg.seedAccess = seedAccess(rep);
    trace = generate_arrivals(cfg);

    for p = 1:numel(policies)
        cfg.policy = char(policies(p));
        r = simulate_network(cfg, trace);

        % Check packet conservation for the complete simulation.
        assert(r.conservation.balanced, ...
            'Conservation failed: rep=%d, policy=%s', rep, cfg.policy)

        % Store outstanding packets by AP and checkpoint.
        outstanding = zeros(cfg.numAPs, numel(checkpoint));

        for ap = 1:cfg.numAPs
            at = trace.times{ap};
            ct = r.completions.completionTime{ap};

            outstanding(ap,:) = arrayfun( ...
                @(x) nnz(at <= x) - nnz(ct <= x), checkpoint);

            m = r.perAP(ap);

            % Verify that the final checkpoint matches the engine result.
            assert(outstanding(ap,end) == m.unfinished)

            % Record AP-level metrics.
            % Network-level airtime and drops are stored in the AP=0 row.
            rows(end+1,:) = { ...
                1, totalLambda, rep, cfg.seedArrival, cfg.seedAccess, ...
                policies(p), ap, cfg.Tsim-cfg.Twarmup, ...
                numel(at), numel(ct), m.completedPackets, ...
                m.p95Delay, m.goodput, NaN, NaN, m.unfinished, ...
                outstanding(ap,1), outstanding(ap,3)};
        end

        % Use AP=0 to identify network-level metrics.
        c = r.conservation;
        g = r.aggregate;

        rows(end+1,:) = { ...
            1, totalLambda, rep, cfg.seedArrival, cfg.seedAccess, ...
            policies(p), 0, cfg.Tsim-cfg.Twarmup, ...
            c.arrivals, c.completions, ...
            sum([r.perAP.completedPackets]), ...
            g.p95Delay, g.goodput, g.ctrlAirtime, c.dropped, ...
            c.unfinished, sum(outstanding(:,1)), ...
            sum(outstanding(:,3))};

        % Retain file naming compatibility with the main graph batch.
        name = sprintf('load_%02d_rep_%02d_%s.mat', ...
            1, rep, cfg.policy);

        save(fullfile(outDir, name), ...
            'cfg', 'trace', 'r', 'checkpoint', 'outstanding')
    end

    % Update the metrics CSV after all policies finish a replication.
    metricsTable = cell2table(rows, 'VariableNames', rowNames);
    writetable(metricsTable, fullfile(outDir, 'run_metrics.csv'));

    fprintf('Completed scenario 1/1, seed pair %d/%d\n', rep, nRep)
end

% Check output counts and network-level packet conservation.
expectedRuns = nRep * numel(policies);
expectedRows = expectedRuns * (base.numAPs + 1);

G = metricsTable(metricsTable.AP == 0, :);
runFiles = dir(fullfile(outDir, 'load_*.mat'));

assert(height(metricsTable) == expectedRows)
assert(height(G) == expectedRuns)
assert(numel(runFiles) == expectedRuns)
assert(all(abs(G.TotalLambda-totalLambda) < 1e-12))
assert(all(G.NArrived == ...
    G.NCompletedTotal + G.Unfinished + G.Dropped))

% Verify matching arrival counts across policies.
for rep = 1:nRep
    arrivalCounts = G.NArrived(G.Repeat == rep);
    assert(numel(arrivalCounts) == numel(policies))
    assert(all(arrivalCounts == arrivalCounts(1)))
end

fprintf('\nBatch checks passed: %d runs and %d metric rows.\n', ...
    expectedRuns, expectedRows);
fprintf('Batch outputs: %s\n', outDir);