clear

% Configure independent replications and policies.
nRep = 20;
totalLambda = 0.30;
policies = ["random", "rr", "queue"];

% Define conflict graphs with zero through three edges.
graphList = { ...
    zeros(0,2), ...
    [1 2], ...
    [1 2; 2 3], ...
    [1 2; 2 3; 1 3]};

graphNames = ["No edges"; "Single edge"; "Path"; "Complete"];
edgeCounts = [0; 1; 2; 3];
nScenarios = numel(graphList);

% Create a separate output directory for this batch.
batchID = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile('results', "D_graph_" + batchID);
mkdir(outDir)

% Configure the shared engine and balanced traffic.
base = default_config();
base.Tsim = 10000;
base.Twarmup = 1000;
base.lambda = totalLambda * [1 1 1] / 3;
base.maxConcurrentAPs = 2;
base.snapshotTime = 'before_ctrl';
base.Tctrl = 0.10 * base.Tdata;

% The coordinated policies retain the concurrency cap of two.
% The random-access baseline follows the existing engine rules.

% Define checkpoints and separate arrival and access seeds.
checkpoint = linspace(base.Twarmup, base.Tsim, 5);
seedArrival = 10000 + (1:nRep);
seedAccess = 20000 + (1:nRep);

% Save the mapping between scenario IDs and graph configurations.
% LoadID is retained for compatibility with the existing metrics format.
scenarioID = (1:nScenarios)';
edgeDefinitions = ["[]"; "[1 2]"; "[1 2; 2 3]"; ...
    "[1 2; 2 3; 1 3]"];

scenarioTable = table( ...
    scenarioID, edgeCounts, graphNames, edgeDefinitions, ...
    repmat(totalLambda, nScenarios, 1), ...
    repmat(base.maxConcurrentAPs, nScenarios, 1), ...
    'VariableNames', {'LoadID','EdgeCount','GraphName','GraphEdges', ...
    'TotalLambda','MaxConcurrentAPs'});

writetable(scenarioTable, fullfile(outDir, 'scenario_manifest.csv'));

% Save all batch settings needed for reproduction.
save(fullfile(outDir, 'batch_config.mat'), ...
    'base', 'nRep', 'totalLambda', 'policies', ...
    'graphList', 'graphNames', 'edgeCounts', ...
    'checkpoint', 'seedArrival', 'seedAccess', 'scenarioTable')

disp(scenarioTable)

% Define the output table columns.
rows = cell(0, 18);
rowNames = {'LoadID','TotalLambda','Repeat','SeedArrival','SeedAccess', ...
    'Policy','AP','MeasureTime','NArrived','NCompletedTotal', ...
    'NCompletedWindow','P95','Goodput','CtrlAirtime','Dropped', ...
    'Unfinished','OutstandingAtWarmup','OutstandingAtMidpoint'};

% Run each graph configuration.
for k = 1:nScenarios
    cfg = base;
    cfg.graphEdges = graphList{k};

    assert(size(cfg.graphEdges,1) == edgeCounts(k))
    assert(abs(sum(cfg.lambda) - totalLambda) < 1e-12)

    fprintf('\nScenario %d/%d: %s, edges=%d\n', ...
        k, nScenarios, char(graphNames(k)), edgeCounts(k));

    % Reusing arrival seeds gives identical traffic across graph scenarios.
    % Within each replication, all policies receive the same trace.
    for rep = 1:nRep
        cfg.seedArrival = seedArrival(rep);
        cfg.seedAccess = seedAccess(rep);
        trace = generate_arrivals(cfg);

        for p = 1:numel(policies)
            cfg.policy = char(policies(p));
            r = simulate_network(cfg, trace);

            % Check packet conservation for the complete simulation.
            assert(r.conservation.balanced, ...
                'Conservation failed: scenario=%d, rep=%d, policy=%s', ...
                k, rep, cfg.policy)

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

                % Store AP-level metrics.
                % Network-level airtime and drops are recorded in the AP=0 row.
                rows(end+1,:) = { ...
                    k, totalLambda, rep, cfg.seedArrival, cfg.seedAccess, ...
                    policies(p), ap, cfg.Tsim-cfg.Twarmup, ...
                    numel(at), numel(ct), m.completedPackets, ...
                    m.p95Delay, m.goodput, NaN, NaN, m.unfinished, ...
                    outstanding(ap,1), outstanding(ap,3)};
            end

            % Use AP=0 to identify network-level metrics.
            c = r.conservation;
            g = r.aggregate;

            rows(end+1,:) = { ...
                k, totalLambda, rep, cfg.seedArrival, cfg.seedAccess, ...
                policies(p), 0, cfg.Tsim-cfg.Twarmup, ...
                c.arrivals, c.completions, ...
                sum([r.perAP.completedPackets]), ...
                g.p95Delay, g.goodput, g.ctrlAirtime, c.dropped, ...
                c.unfinished, sum(outstanding(:,1)), ...
                sum(outstanding(:,3))};

            % Save the configuration, arrival trace, and complete run result.
            % Load-based file names are retained for format compatibility.
            name = sprintf('load_%02d_rep_%02d_%s.mat', ...
                k, rep, cfg.policy);

            save(fullfile(outDir, name), ...
                'cfg', 'trace', 'r', 'checkpoint', 'outstanding')
        end

        % Update the metrics CSV after all policies finish a replication.
        metricsTable = cell2table(rows, 'VariableNames', rowNames);
        writetable(metricsTable, fullfile(outDir, 'run_metrics.csv'));

        fprintf('Completed scenario %d/%d, seed pair %d/%d\n', ...
            k, nScenarios, rep, nRep)
    end
end

% Check the expected output size and network-level packet conservation.
expectedRuns = nScenarios * nRep * numel(policies);
expectedRows = expectedRuns * (base.numAPs + 1);

G = metricsTable(metricsTable.AP == 0, :);
runFiles = dir(fullfile(outDir, 'load_*.mat'));

assert(height(metricsTable) == expectedRows)
assert(height(G) == expectedRuns)
assert(numel(runFiles) == expectedRuns)
assert(all(abs(G.TotalLambda - totalLambda) < 1e-12))
assert(all(G.NArrived == ...
    G.NCompletedTotal + G.Unfinished + G.Dropped))

% Check matching arrival counts across policies and graph scenarios.
for rep = 1:nRep
    selected = G.Repeat == rep;
    arrivalCounts = G.NArrived(selected);

    assert(numel(arrivalCounts) == nScenarios*numel(policies))
    assert(all(arrivalCounts == arrivalCounts(1)))
end

fprintf('\nBatch checks passed: %d runs and %d metric rows.\n', ...
    expectedRuns, expectedRows);
fprintf('Batch outputs: %s\n', outDir);