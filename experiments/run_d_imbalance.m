clear

% Configure independent replications and traffic splits.
nRep = 20;
totalLambda = 0.30;
weights = [1 1 1; 1 3 1; 1 6 1];
policies = ["random", "rr", "queue"];
nScenarios = size(weights, 1);

% Create a separate output directory for this batch.
batchID = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile('results', "D_imbalance_" + batchID);
mkdir(outDir)

% Configure the shared engine for the path-graph experiment.
base = default_config();
base.Tsim = 10000;
base.Twarmup = 1000;
base.graphEdges = [1 2; 2 3];
base.maxConcurrentAPs = 2;
base.snapshotTime = 'before_ctrl';
base.Tctrl = 0.10 * base.Tdata;

% Define checkpoints and separate arrival and access seeds.
checkpoint = linspace(base.Twarmup, base.Tsim, 5);
seedArrival = 10000 + (1:nRep);
seedAccess = 20000 + (1:nRep);

% Normalize every traffic split to the same total arrival rate.
rates = totalLambda * weights ./ sum(weights, 2);
assert(all(abs(sum(rates, 2) - totalLambda) < 1e-12))

% Save the mapping between scenario IDs and traffic configurations.
% LoadID is retained for compatibility with the existing metrics format.
scenarioID = (1:nScenarios)';
scenarioTable = table( ...
    scenarioID, weights(:,1), weights(:,2), weights(:,3), ...
    rates(:,1), rates(:,2), rates(:,3), ...
    'VariableNames', {'LoadID','WeightAP1','WeightAP2','WeightAP3', ...
    'LambdaAP1','LambdaAP2','LambdaAP3'});

writetable(scenarioTable, fullfile(outDir, 'scenario_manifest.csv'));

% Save all batch settings needed for reproduction.
save(fullfile(outDir, 'batch_config.mat'), ...
    'base', 'nRep', 'totalLambda', 'weights', 'rates', ...
    'policies', 'checkpoint', 'seedArrival', 'seedAccess', ...
    'scenarioTable')

disp(scenarioTable)

% Define the output table columns.
rows = cell(0, 18);
rowNames = {'LoadID','TotalLambda','Repeat','SeedArrival','SeedAccess', ...
    'Policy','AP','MeasureTime','NArrived','NCompletedTotal', ...
    'NCompletedWindow','P95','Goodput','CtrlAirtime','Dropped', ...
    'Unfinished','OutstandingAtWarmup','OutstandingAtMidpoint'};

% Run each traffic-imbalance scenario.
for k = 1:nScenarios
    cfg = base;
    cfg.lambda = rates(k,:);

    assert(abs(sum(cfg.lambda) - totalLambda) < 1e-12)

    fprintf('\nScenario %d/%d: traffic weights %d:%d:%d\n', ...
        k, nScenarios, weights(k,1), weights(k,2), weights(k,3));

    % Generate one arrival trace per replication and share it across policies.
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
            % File names retain the existing load-based naming convention.
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

% Verify that all policies received the same number of arrivals per replication.
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