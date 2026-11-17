clear

% Configure the number of independent replications and offered loads.
nRep = 20;
loads = [0.15 0.30 0.45];
policies = ["random", "rr", "queue"];

% Create a separate output directory for this batch.
batchID = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile('results', "D_load_" + batchID);
mkdir(outDir)

% Configure the shared engine for the balanced path-graph experiment.
base = default_config();
base.Tsim = 10000;
base.Twarmup = 1000;
base.graphEdges = [1 2; 2 3];
base.maxConcurrentAPs = 2;
base.snapshotTime = 'before_ctrl';
base.Tctrl = 0.10 * base.Tdata;

% Define backlog checkpoints and separate arrival and access seeds.
checkpoint = linspace(base.Twarmup, base.Tsim, 5);
seedArrival = 10000 + (1:nRep);
seedAccess = 20000 + (1:nRep);

% Save the batch configuration and seed lists.
save(fullfile(outDir, 'batch_config.mat'), ...
    'base', 'loads', 'policies', 'checkpoint', ...
    'seedArrival', 'seedAccess')

% Define the output table columns.
rows = cell(0, 18);
rowNames = {'LoadID','TotalLambda','Repeat','SeedArrival','SeedAccess', ...
    'Policy','AP','MeasureTime','NArrived','NCompletedTotal', ...
    'NCompletedWindow','P95','Goodput','CtrlAirtime','Dropped', ...
    'Unfinished','OutstandingAtWarmup','OutstandingAtMidpoint'};

% Run each offered-load configuration.
for k = 1:numel(loads)
    cfg = base;
    cfg.lambda = loads(k) * [1 1 1] / 3;

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
                'Conservation failed: load=%d, rep=%d, policy=%s', ...
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
                    k, loads(k), rep, cfg.seedArrival, cfg.seedAccess, ...
                    policies(p), ap, cfg.Tsim-cfg.Twarmup, ...
                    numel(at), numel(ct), m.completedPackets, ...
                    m.p95Delay, m.goodput, NaN, NaN, m.unfinished, ...
                    outstanding(ap,1), outstanding(ap,3)};
            end

            % Use AP=0 to identify network-level metrics.
            c = r.conservation;
            g = r.aggregate;

            rows(end+1,:) = { ...
                k, loads(k), rep, cfg.seedArrival, cfg.seedAccess, ...
                policies(p), 0, cfg.Tsim-cfg.Twarmup, ...
                c.arrivals, c.completions, ...
                sum([r.perAP.completedPackets]), ...
                g.p95Delay, g.goodput, g.ctrlAirtime, c.dropped, ...
                c.unfinished, sum(outstanding(:,1)), ...
                sum(outstanding(:,3))};

            % Save the configuration, arrival trace, and complete run result.
            name = sprintf('load_%02d_rep_%02d_%s.mat', ...
                k, rep, cfg.policy);

            save(fullfile(outDir, name), ...
                'cfg', 'trace', 'r', 'checkpoint', 'outstanding')
        end

        % Update the metrics CSV after all policies finish a replication.
        writetable(cell2table(rows, 'VariableNames', rowNames), ...
            fullfile(outDir, 'run_metrics.csv'))

        fprintf('Completed load %d/%d, seed pair %d/%d\n', ...
            k, numel(loads), rep, nRep)
    end
end

fprintf('Batch outputs: %s\n', outDir)