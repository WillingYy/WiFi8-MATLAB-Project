clear
close all

% Select the completed imbalance batch.
batchDir = uigetdir(fullfile(pwd, 'results'), ...
    'Select the D_imbalance batch folder');
if isequal(batchDir, 0)
    return
end

T = readtable(fullfile(batchDir, 'run_metrics.csv'));
T.Policy = string(T.Policy);
M = readtable(fullfile(batchDir, 'scenario_manifest.csv'));
M = sortrows(M, 'LoadID');

policies = ["random", "rr", "queue"];
labels = {'Random access', 'Round-robin', 'Queue-aware'};
colors = lines(3);
markers = {'o', 's', '^'};
styles = {'-', '--', ':'};

nScenarios = height(M);
splitLabels = compose('%d:%d:%d', ...
    M.WeightAP1, M.WeightAP2, M.WeightAP3);

% Create a separate analysis directory for each execution.
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
analysisDir = fullfile(batchDir, ['analysis_' stamp]);
mkdir(analysisDir)

% Use identical bootstrap indices for paired policies in each scenario.
bsStream = RandStream('mt19937ar', 'Seed', 30002);
nBootstrap = 5000;

meanP95 = nan(nScenarios, 3, 4);
lowP95 = nan(nScenarios, 3, 4);
highP95 = nan(nScenarios, 3, 4);
meanGoodput = nan(nScenarios, 3, 4);
meanUnfinished = nan(nScenarios, 3, 4);
rows = cell(0, 13);
pairedRows = cell(0, 7);

for k = 1:nScenarios
    scenarioID = M.LoadID(k);
    bootstrapIdx = randi(bsStream, 20, 20, nBootstrap);
    runP95 = nan(20, 3, 4);

    for p = 1:3
        for ap = 0:3
            S = T(T.LoadID == scenarioID & ...
                T.Policy == policies(p) & T.AP == ap, :);
            S = sortrows(S, 'Repeat');

            assert(height(S) == 20)
            assert(isequal(S.Repeat, (1:20)'))

            a = ap + 1;
            x = S.P95;
            runP95(:,p,a) = x;
            nValid = nnz(isfinite(x));

            % Keep undefined percentiles visible in the summary.
            % Estimate a confidence interval only when all runs are valid.
            if nValid == 20
                bootMeans = mean(x(bootstrapIdx), 1);
                meanP95(k,p,a) = mean(x);
                lowP95(k,p,a) = my_quantile(bootMeans, 0.025);
                highP95(k,p,a) = my_quantile(bootMeans, 0.975);
            else
                warning('Scenario %d, %s, AP%d has %d/20 valid P95 values.', ...
                    scenarioID, char(policies(p)), ap, nValid)
            end

            meanGoodput(k,p,a) = mean(S.Goodput);
            meanUnfinished(k,p,a) = mean(S.Unfinished);

            rows(end+1,:) = {scenarioID, splitLabels(k), policies(p), ...
                ap, nValid, meanP95(k,p,a), lowP95(k,p,a), ...
                highP95(k,p,a), mean(S.Goodput), ...
                min(S.NCompletedWindow), mean(S.Unfinished), ...
                max(S.Unfinished), mean(S.CtrlAirtime)};
        end
    end

    % Positive paired differences indicate lower P95 under queue awareness.
    for ap = 0:3
        d = runP95(:,2,ap+1) - runP95(:,3,ap+1);
        validPairs = nnz(isfinite(d));
        estimate = NaN;
        lower = NaN;
        upper = NaN;

        if validPairs == 20
            bootstrapDifference = mean(d(bootstrapIdx), 1);
            estimate = mean(d);
            lower = my_quantile(bootstrapDifference, 0.025);
            upper = my_quantile(bootstrapDifference, 0.975);
        end

        pairedRows(end+1,:) = {scenarioID, splitLabels(k), ap, ...
            validPairs, estimate, lower, upper};
    end
end

% Save network-level and per-AP statistics.
summaryTable = cell2table(rows, 'VariableNames', ...
    {'LoadID','TrafficSplit','Policy','AP','ValidP95Runs', ...
     'MeanP95','CI_Low','CI_High','MeanGoodput', ...
     'MinCompletedWindow','MeanUnfinished','MaxUnfinished', ...
     'MeanCtrlAirtime'});

pairedTable = cell2table(pairedRows, 'VariableNames', ...
    {'LoadID','TrafficSplit','AP','ValidPairs', ...
     'Mean_RR_Minus_Queue','CI_Low','CI_High'});

writetable(summaryTable, fullfile(analysisDir, 'imbalance_summary.csv'));
writetable(pairedTable, fullfile(analysisDir, 'rr_queue_paired.csv'));

disp(summaryTable(summaryTable.AP == 0, :))
disp(pairedTable)

% Create six panels with explicit margins.
f = figure('Color', 'w', 'Position', [80 80 1600 1000]);
ax = gobjects(6,1);

left = 0.075;
bottom = 0.085;
width = 0.24;
heightPanel = 0.355;
columnGap = 0.08;
rowGap = 0.14;

for panel = 1:6
    col = mod(panel-1, 3);
    row = floor((panel-1)/3);
    ax(panel) = axes('Parent', f, 'Position', ...
        [left+col*(width+columnGap), ...
         bottom+(1-row)*(heightPanel+rowGap), width, heightPanel], ...
        'FontName', 'Arial', 'FontSize', 10, ...
        'Box', 'on', 'TickDir', 'out');
    hold(ax(panel), 'on')
    grid(ax(panel), 'on')
    ax(panel).GridAlpha = 0.15;
    xlim(ax(panel), [0.8 nScenarios+0.2])
    xticks(ax(panel), 1:nScenarios)
    xticklabels(ax(panel), splitLabels)
    xlabel(ax(panel), 'Traffic split (AP1:AP2:AP3)')
end

% Plot overall and per-AP P95 with bootstrap confidence intervals.
panelAP = [0 1 2 3];
panelTitles = {'Overall P95', 'AP1 P95', ...
    'AP2 P95 (hotspot in unequal splits)', 'AP3 P95'};

for panel = 1:4
    a = panelAP(panel)+1;
    for p = 1:3
        y = meanP95(:,p,a);
        errorbar(ax(panel), 1:nScenarios, y, ...
            y-lowP95(:,p,a), highP95(:,p,a)-y, ...
            'Color', colors(p,:), 'LineStyle', styles{p}, ...
            'Marker', markers{p}, 'MarkerSize', 6, ...
            'LineWidth', 1.4, 'CapSize', 8, ...
            'DisplayName', labels{p});
    end
    title(ax(panel), panelTitles{panel}, 'FontSize', 11)
    ylabel(ax(panel), 'Mean run P95 (time units)')
    legend(ax(panel), 'Location', 'best', 'FontSize', 9)
    ylim(ax(panel), 'padded')
end

% Compare hotspot goodput with its configured offered payload rate.
for p = 1:3
    plot(ax(5), 1:nScenarios, meanGoodput(:,p,3), ...
        'Color', colors(p,:), 'LineStyle', styles{p}, ...
        'Marker', markers{p}, 'LineWidth', 1.4, ...
        'DisplayName', labels{p});
end

settings = load(fullfile(batchDir, 'batch_config.mat'), 'base');
plot(ax(5), 1:nScenarios, ...
    M.LambdaAP2*settings.base.packetBits, 'k-.', ...
    'DisplayName', 'AP2 offered payload rate');
title(ax(5), 'AP2 goodput', 'FontSize', 11)
ylabel(ax(5), 'Goodput (bits/time unit)')
legend(ax(5), 'Location', 'best', 'FontSize', 9)
ylim(ax(5), 'padded')

% Display network-level unfinished packets at the simulation endpoint.
for p = 1:3
    plot(ax(6), 1:nScenarios, meanUnfinished(:,p,1), ...
        'Color', colors(p,:), 'LineStyle', styles{p}, ...
        'Marker', markers{p}, 'LineWidth', 1.4, ...
        'DisplayName', labels{p});
end
title(ax(6), 'End-of-run unfinished packets', 'FontSize', 11)
ylabel(ax(6), 'Mean unfinished packets')
legend(ax(6), 'Location', 'best', 'FontSize', 9)
ylim(ax(6), 'padded')

% Export the full canvas to preserve outer whitespace.
drawnow
set(f, 'PaperPositionMode', 'auto', 'PaperUnits', 'inches');
paperPosition = get(f, 'PaperPosition');
set(f, 'PaperSize', paperPosition(3:4));

print(f, fullfile(analysisDir, 'imbalance_results.png'), '-dpng', '-r300');
print(f, fullfile(analysisDir, 'imbalance_results.pdf'), '-dpdf', '-painters');
savefig(f, fullfile(analysisDir, 'imbalance_results.fig'));

fprintf('Analysis outputs: %s\n', analysisDir)
winopen(analysisDir)