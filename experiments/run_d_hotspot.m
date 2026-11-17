clear

% Configure independent replications and policies.
nRep = 20;
totalLambda = 0.30;
policies = ["random", "rr", "queue"];

% Compare centre and endpoint hotspots on the same path graph.
weights = [1 6 1; 6 1 1];
hotspotAP = [2; 1];
scenarioNames = ["Centre hotspot"; "Endpoint hotspot"];
nScenarios = size(weights, 1);

% Create a separate output directory for this batch.
batchID = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile('results', "D_hotspot_" + batchID);
mkdir(outDir)

% Configure the shared engine.
base = default_config();
base.Tsim = 10000;
base.Twarmup = 1000;
base.graphEdges = [1 2; 2 3];
base.maxConcurrentAPs = 2;
base.snapshotTime = 'before_ctrl';
base.Tctrl = 0.10 * base.Tdata;

% Normalize traffic weights to the same total arrival rate.
rates = totalLambda * weights ./ sum(weights, 2);
assert(all(abs(sum(rates, 2) - totalLambda) < 1e-12))

% Define checkpoints and separate arrival and access seeds.
checkpoint = linspace(base.Twarmup, base.Tsim, 5);
seedArrival = 10000 + (1:nRep);
seedAccess = 20000 + (1:nRep);

% Save the mapping between scenario IDs, traffic splits, and hotspot roles.
% LoadID is retained for compatibility with the existing metrics format.
scenarioID = (1:nScenarios)';
scenarioTable = table( ...
    scenarioID, scenarioNames, hotspotAP, ...
    weights(:,1), weights(:,2), weights(:,3), ...
    rates(:,1), rates(:,2), rates(:,3), ...
    'VariableNames', {'LoadID','ScenarioName','HotspotAP', ...
    'WeightAP1','WeightAP2','WeightAP3', ...
    'LambdaAP1','LambdaAP2','LambdaAP3'});

writetable(scenarioTable, fullfile(outDir, 'scenario_manifest.csv'));

% Save all batch settings needed for reproduction.
save(fullfile(outDir, 'batch_config.mat'), ...
    'base', 'nRep', 'totalLambda', 'policies', ...
    'weights', 'rates', 'hotspotAP', 'scenarioNames', ...
    'checkpoint', 'seedArrival', 'seedAccess', 'scenarioTable')

disp(scenarioTable)

% Define the output table columns.
rows = cell(0, 18);
rowNames = {'LoadID','TotalLambda','Repeat','SeedArrival','SeedAccess', ...
    'Policy','AP','MeasureTime','NArrived','NCompletedTotal', ...
    'NCompletedWindow','P95','Goodput','CtrlAirtime','Dropped', ...
    'Unfinished','OutstandingAtWarmup','OutstandingAtMidpoint'};

% Run each hotspot-location scenario.
for k = 1:nScenarios
    cfg = base;
    cfg.lambda = rates(k,:);

    assert(abs(sum(cfg.lambda) - totalLambda) < 1e-12)

    fprintf('\nScenario %d/%d: %s, hotspot AP%d\n', ...
        k, nScenarios, char(scenarioNames(k)), hotspotAP(k));

    % Generate one arrival trace per replication and share it across policies.
    % Each hotspot scenario uses its own configured per-AP arrival rates.
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

% Check output counts and network-level packet conservation.
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

% Verify matching arrival counts across policies within each scenario.
for k = 1:nScenarios
    for rep = 1:nRep
        selected = G.LoadID == k & G.Repeat == rep;
        arrivalCounts = G.NArrived(selected);

        assert(numel(arrivalCounts) == numel(policies))
        assert(all(arrivalCounts == arrivalCounts(1)))
    end
end

fprintf('\nBatch checks passed: %d runs and %d metric rows.\n', ...
    expectedRuns, expectedRows);
fprintf('Batch outputs: %s\n', outDir);