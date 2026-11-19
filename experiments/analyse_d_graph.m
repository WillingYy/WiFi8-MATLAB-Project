clear
close all

% Select the completed graph experiment batch.
batchDir = uigetdir(fullfile(pwd, 'results'), ...
    'Select the D_graph batch folder');
if isequal(batchDir, 0)
    return
end

T = readtable(fullfile(batchDir, 'run_metrics.csv'));
T.Policy = string(T.Policy);

M = readtable(fullfile(batchDir, 'scenario_manifest.csv'));
M = sortrows(M, 'EdgeCount');

settings = load(fullfile(batchDir, 'batch_config.mat'), ...
    'base', 'nRep', 'totalLambda');

nRep = settings.nRep;
nScenarios = height(M);
policies = ["random", "rr", "queue"];
labels = {'Random access', 'Round-robin', 'Queue-aware'};
colors = lines(3);
markers = {'o', 's', '^'};
styles = {'-', '--', ':'};

% Create a separate analysis directory for each execution.
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
analysisDir = fullfile(batchDir, ['analysis_' stamp]);
mkdir(analysisDir)

% Configure reproducible bootstrap resampling.
bsStream = RandStream('mt19937ar', 'Seed', 30003);
nBootstrap = 5000;

meanP95 = nan(nScenarios, 3, 4);
lowP95 = nan(nScenarios, 3, 4);
highP95 = nan(nScenarios, 3, 4);
meanGoodput = nan(nScenarios, 3, 4);
meanUnfinished = nan(nScenarios, 3, 4);
meanCtrl = nan(nScenarios, 3);

summaryRows = cell(0, 14);
pairedRows = cell(0, 9);

for k = 1:nScenarios
    scenarioID = M.LoadID(k);

    % Reuse bootstrap indices across policies to preserve pairing.
    bootstrapIdx = randi(bsStream, nRep, nRep, nBootstrap);
    runP95 = nan(nRep, 3, 4);

    for p = 1:3
        for ap = 0:3
            S = T(T.LoadID == scenarioID & ...
                T.Policy == policies(p) & T.AP == ap, :);
            S = sortrows(S, 'Repeat');

            assert(height(S) == nRep)
            assert(isequal(S.Repeat, (1:nRep)'))

            a = ap + 1;
            x = S.P95;
            runP95(:,p,a) = x;
            nValid = nnz(isfinite(x));

            % Preserve missing percentiles explicitly.
            if nValid == nRep
                bootstrapMeans = mean(x(bootstrapIdx), 1);
                meanP95(k,p,a) = mean(x);
                lowP95(k,p,a) = my_quantile(bootstrapMeans, 0.025);
                highP95(k,p,a) = my_quantile(bootstrapMeans, 0.975);
            else
                warning('Scenario %d, %s, AP%d: %d/%d valid P95 runs.', ...
                    scenarioID, char(policies(p)), ap, nValid, nRep)
            end

            meanGoodput(k,p,a) = mean(S.Goodput);
            meanUnfinished(k,p,a) = mean(S.Unfinished);

            % Record control airtime only at network level.
            ctrl = NaN;
            if ap == 0
                ctrl = mean(S.CtrlAirtime);
                meanCtrl(k,p) = ctrl;
            end

            summaryRows(end+1,:) = { ...
                scenarioID, M.EdgeCount(k), string(M.GraphName(k)), ...
                policies(p), ap, nValid, ...
                meanP95(k,p,a), lowP95(k,p,a), highP95(k,p,a), ...
                mean(S.Goodput), min(S.NCompletedWindow), ...
                mean(S.Unfinished), max(S.Unfinished), ctrl};
        end
    end

    % Positive differences indicate lower P95 under the second policy.
    comparisonPairs = [1 2; 1 3; 2 3];
    comparisonNames = ["Random minus RR"; ...
        "Random minus Queue"; "RR minus Queue"];

    for comparison = 1:size(comparisonPairs,1)
        first = comparisonPairs(comparison,1);
        second = comparisonPairs(comparison,2);

        for ap = 0:3
            d = runP95(:,first,ap+1) - runP95(:,second,ap+1);
            validPairs = nnz(isfinite(d));
            estimate = NaN;
            lower = NaN;
            upper = NaN;

            if validPairs == nRep
                bootstrapDifference = mean(d(bootstrapIdx), 1);
                estimate = mean(d);
                lower = my_quantile(bootstrapDifference, 0.025);
                upper = my_quantile(bootstrapDifference, 0.975);
            end

            pairedRows(end+1,:) = { ...
                scenarioID, M.EdgeCount(k), ...
                comparisonNames(comparison), ap, validPairs, ...
                estimate, lower, upper, nRep};
        end
    end
end

% Save network-level and per-AP summary statistics.
summaryTable = cell2table(summaryRows, 'VariableNames', ...
    {'LoadID','EdgeCount','GraphName','Policy','AP','ValidP95Runs', ...
     'MeanP95','CI_Low','CI_High','MeanGoodput', ...
     'MinCompletedWindow','MeanUnfinished','MaxUnfinished', ...
     'MeanCtrlAirtime'});

pairedTable = cell2table(pairedRows, 'VariableNames', ...
    {'LoadID','EdgeCount','Comparison','AP','ValidPairs', ...
     'MeanDifference','CI_Low','CI_High','ExpectedPairs'});

writetable(summaryTable, fullfile(analysisDir, 'graph_summary.csv'));
writetable(pairedTable, fullfile(analysisDir, 'graph_paired.csv'));

disp(summaryTable(summaryTable.AP == 0, :))
disp(pairedTable(pairedTable.AP == 0, :))

% Create six panels with explicit outer margins.
f = figure('Color', 'w', 'Position', [80 80 1600 1000]);
ax = gobjects(6,1);

for panel = 1:6
    col = mod(panel-1, 3);
    row = floor((panel-1)/3);

    ax(panel) = axes('Parent', f, 'Position', ...
        [0.075+col*0.32, 0.085+(1-row)*0.495, 0.24, 0.355], ...
        'FontName', 'Arial', 'FontSize', 10, ...
        'Box', 'on', 'TickDir', 'out');

    hold(ax(panel), 'on')
    grid(ax(panel), 'on')
    ax(panel).GridAlpha = 0.15;
    xlim(ax(panel), [-0.2 3.2])
    xticks(ax(panel), M.EdgeCount)
    xlabel(ax(panel), 'Number of interference edges')
end

% Plot overall P95 and AP2 P95 with 95% bootstrap intervals.
p95APIndices = [1 3];
p95Titles = {'Overall P95', 'AP2 P95'};

for panel = 1:2
    a = p95APIndices(panel);

    for p = 1:3
        y = meanP95(:,p,a);
        errorbar(ax(panel), M.EdgeCount, y, ...
            y-lowP95(:,p,a), highP95(:,p,a)-y, ...
            'Color', colors(p,:), 'LineStyle', styles{p}, ...
            'Marker', markers{p}, 'MarkerSize', 6, ...
            'LineWidth', 1.4, 'CapSize', 8, ...
            'DisplayName', labels{p});
    end

    title(ax(panel), p95Titles{panel}, 'FontSize', 11)
    ylabel(ax(panel), 'Mean run P95 (time units)')
end

% Plot aggregate goodput and the configured offered payload rate.
for p = 1:3
    plot(ax(3), M.EdgeCount, meanGoodput(:,p,1), ...
        'Color', colors(p,:), 'LineStyle', styles{p}, ...
        'Marker', markers{p}, 'LineWidth', 1.4, ...
        'DisplayName', labels{p});
end

offeredTotal = settings.totalLambda * settings.base.packetBits;
yline(ax(3), offeredTotal, 'k-.', ...
    'DisplayName', 'Offered payload rate');
title(ax(3), 'Aggregate goodput', 'FontSize', 11)
ylabel(ax(3), 'Goodput (bits/time unit)')

% Plot network-level control airtime as a percentage.
for p = 1:3
    plot(ax(4), M.EdgeCount, 100*meanCtrl(:,p), ...
        'Color', colors(p,:), 'LineStyle', styles{p}, ...
        'Marker', markers{p}, 'LineWidth', 1.4, ...
        'DisplayName', labels{p});
end
title(ax(4), 'Coordination airtime', 'FontSize', 11)
ylabel(ax(4), 'Control airtime (%)')

% Plot outstanding packets at the simulation endpoint.
for p = 1:3
    plot(ax(5), M.EdgeCount, meanUnfinished(:,p,1), ...
        'Color', colors(p,:), 'LineStyle', styles{p}, ...
        'Marker', markers{p}, 'LineWidth', 1.4, ...
        'DisplayName', labels{p});
end
title(ax(5), 'End-of-run unfinished packets', 'FontSize', 11)
ylabel(ax(5), 'Mean unfinished packets')

% Plot AP2 goodput and its configured offered payload rate.
for p = 1:3
    plot(ax(6), M.EdgeCount, meanGoodput(:,p,3), ...
        'Color', colors(p,:), 'LineStyle', styles{p}, ...
        'Marker', markers{p}, 'LineWidth', 1.4, ...
        'DisplayName', labels{p});
end

offeredAP2 = settings.base.lambda(2) * settings.base.packetBits;
yline(ax(6), offeredAP2, 'k-.', ...
    'DisplayName', 'AP2 offered payload rate');
title(ax(6), 'AP2 goodput', 'FontSize', 11)
ylabel(ax(6), 'Goodput (bits/time unit)')

for panel = 1:6
    legend(ax(panel), 'Location', 'best', 'FontSize', 9)
    ylim(ax(panel), 'padded')
end

% Use zero-based goodput axes to show the scale of the differences.
totalGoodputValues = meanGoodput(:,:,1);
ap2GoodputValues = meanGoodput(:,:,3);

totalUpper = max([offeredTotal; totalGoodputValues(:)]);
ap2Upper = max([offeredAP2; ap2GoodputValues(:)]);

ylim(ax(3), [0 ceil(1.1*totalUpper/100)*100]);
ylim(ax(6), [0 ceil(1.1*ap2Upper/100)*100]);

% Export the full canvas to preserve outer whitespace.
drawnow
set(f, 'PaperPositionMode', 'auto', 'PaperUnits', 'inches');
paperPosition = get(f, 'PaperPosition');
set(f, 'PaperSize', paperPosition(3:4));

print(f, fullfile(analysisDir, 'graph_results.png'), '-dpng', '-r300');
print(f, fullfile(analysisDir, 'graph_results.pdf'), '-dpdf', '-painters');
savefig(f, fullfile(analysisDir, 'graph_results.fig'));

fprintf('Analysis outputs: %s\n', analysisDir)
winopen(analysisDir)