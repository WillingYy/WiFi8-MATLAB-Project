clear

% Select the main graph batch containing the cap-two reference.
cap2Dir = uigetdir(fullfile(pwd, 'results'), ...
    'Select the original D_graph batch');
if isequal(cap2Dir, 0)
    return
end

% Select the no-edge batch with a concurrency cap of three.
cap3Dir = uigetdir(fullfile(pwd, 'results'), ...
    'Select the D_noedge_cap3 batch');
if isequal(cap3Dir, 0)
    return
end

A = readtable(fullfile(cap2Dir, 'run_metrics.csv'));
B = readtable(fullfile(cap3Dir, 'run_metrics.csv'));
A.Policy = string(A.Policy);
B.Policy = string(B.Policy);

% Locate the no-edge scenario in each batch.
MA = readtable(fullfile(cap2Dir, 'scenario_manifest.csv'));
MB = readtable(fullfile(cap3Dir, 'scenario_manifest.csv'));
idA = MA.LoadID(MA.EdgeCount == 0);
idB = MB.LoadID(MB.EdgeCount == 0);

assert(isscalar(idA) && isscalar(idB))
assert(MA.MaxConcurrentAPs(MA.LoadID == idA) == 2)
assert(MB.MaxConcurrentAPs(MB.LoadID == idB) == 3)

A = A(A.LoadID == idA, :);
B = B(B.LoadID == idB, :);

policies = ["random", "rr", "queue"];
bsStream = RandStream('mt19937ar', 'Seed', 30004);
bootstrapIdx = randi(bsStream, 20, 20, 5000);
rows = cell(0, 15);

for p = 1:numel(policies)
    for ap = 0:3
        S2 = sortrows(A(A.Policy == policies(p) & A.AP == ap, :), ...
            'Repeat');
        S3 = sortrows(B(B.Policy == policies(p) & B.AP == ap, :), ...
            'Repeat');

        % Check replication IDs, seeds, and arrival counts before pairing.
        assert(height(S2) == 20 && height(S3) == 20)
        assert(isequal(S2.Repeat, (1:20)'))
        assert(isequal(S2.Repeat, S3.Repeat))
        assert(isequal(S2.SeedArrival, S3.SeedArrival))
        assert(isequal(S2.SeedAccess, S3.SeedAccess))
        assert(isequal(S2.NArrived, S3.NArrived))

        % Check reproducibility of the unchanged random-access baseline.
        if policies(p) == "random"
            baselineFields = {'P95','Goodput','NCompletedTotal', ...
                'NCompletedWindow','Unfinished','CtrlAirtime'};

            for j = 1:numel(baselineFields)
                field = baselineFields{j};
                assert(isequaln(S2.(field), S3.(field)), ...
                    'Random baseline mismatch in %s, AP%d.', field, ap)
            end
        end

        % Positive P95 differences indicate improvement with cap three.
        difference = S2.P95 - S3.P95;
        validPairs = nnz(isfinite(difference));
        estimate = NaN;
        lower = NaN;
        upper = NaN;
        p95Cap2 = NaN;
        p95Cap3 = NaN;

        if validPairs == 20
            bootstrapMeans = mean(difference(bootstrapIdx), 1);
            estimate = mean(difference);
            lower = my_quantile(bootstrapMeans, 0.025);
            upper = my_quantile(bootstrapMeans, 0.975);
            p95Cap2 = mean(S2.P95);
            p95Cap3 = mean(S3.P95);
        else
            warning('%s, AP%d has %d/20 valid pairs.', ...
                char(policies(p)), ap, validPairs)
        end

        rows(end+1,:) = { ...
            policies(p), ap, validPairs, p95Cap2, p95Cap3, ...
            estimate, lower, upper, ...
            mean(S2.Goodput), mean(S3.Goodput), ...
            mean(S2.Unfinished), mean(S3.Unfinished), ...
            mean(S2.CtrlAirtime), mean(S3.CtrlAirtime), ...
            min([S2.NCompletedWindow; S3.NCompletedWindow])};
    end
end

% Save all AP-level and network-level comparisons.
comparisonTable = cell2table(rows, 'VariableNames', ...
    {'Policy','AP','ValidPairs','MeanP95_Cap2','MeanP95_Cap3', ...
     'MeanP95_Cap2MinusCap3','CI_Low','CI_High', ...
     'MeanGoodput_Cap2','MeanGoodput_Cap3', ...
     'MeanUnfinished_Cap2','MeanUnfinished_Cap3', ...
     'MeanCtrlAirtime_Cap2','MeanCtrlAirtime_Cap3', ...
     'MinCompletedWindow'});

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
analysisDir = fullfile(cap3Dir, ['comparison_' stamp]);
mkdir(analysisDir)

writetable(comparisonTable, ...
    fullfile(analysisDir, 'noedge_cap_comparison.csv'));

disp(comparisonTable(comparisonTable.AP == 0, :))
fprintf('Random-access baseline reproducibility checks passed.\n');
fprintf('Comparison saved to %s\n', analysisDir);
