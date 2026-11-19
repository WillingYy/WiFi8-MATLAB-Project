clear
close all

% Select the completed hotspot batch.
batchDir = uigetdir(fullfile(pwd, 'results'), ...
    'Select the D_hotspot batch folder');
if isequal(batchDir, 0)
    return
end

T = readtable(fullfile(batchDir, 'run_metrics.csv'));
T.Policy = string(T.Policy);
M = readtable(fullfile(batchDir, 'scenario_manifest.csv'));
M = sortrows(M, 'LoadID');
settings = load(fullfile(batchDir, 'batch_config.mat'), 'base', 'nRep');

assert(height(M) == 2)
nRep = settings.nRep;
policies = ["random", "rr", "queue"];
labels = {'Random access', 'Round-robin', 'Queue-aware'};
colors = lines(3);
markers = {'o', 's', '^'};
styles = {'-', '--', ':'};

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
analysisDir = fullfile(batchDir, ['analysis_' stamp]);
mkdir(analysisDir)

% Use shared bootstrap indices for policy comparisons within each scenario.
bsStream = RandStream('mt19937ar', 'Seed', 30005);
nBootstrap = 5000;
rows = cell(0, 15);

for k = 1:2
    idx = randi(bsStream, nRep, nRep, nBootstrap);

    for p = 1:3
        for ap = 0:3
            S = T(T.LoadID == M.LoadID(k) & ...
                T.Policy == policies(p) & T.AP == ap, :);
            S = sortrows(S, 'Repeat');

            assert(height(S) == nRep)
            assert(isequal(S.Repeat, (1:nRep)'))

            role = "Non-hotspot";
            if ap == 0
                role = "Overall";
            elseif ap == M.HotspotAP(k)
                role = "Hotspot";
            end

            % Keep undefined delay estimates explicit.
            valid = nnz(isfinite(S.P95));
            estimate = NaN;
            lower = NaN;
            upper = NaN;

            if valid == nRep
                bootstrapMeans = mean(S.P95(idx), 1);
                estimate = mean(S.P95);
                lower = my_quantile(bootstrapMeans, 0.025);
                upper = my_quantile(bootstrapMeans, 0.975);
            else
                warning('Scenario %d, %s, AP%d: %d valid runs.', ...
                    k, char(policies(p)), ap, valid)
            end

            ctrl = NaN;
            if ap == 0
                ctrl = mean(S.CtrlAirtime);
            end

            rows(end+1,:) = {M.LoadID(k), string(M.ScenarioName(k)), ...
                policies(p), ap, role, valid, estimate, lower, upper, ...
                mean(S.Goodput), min(S.NCompletedWindow), ...
                mean(S.Unfinished), max(S.Unfinished), ...
                mean(S.OutstandingAtWarmup), ctrl};
        end
    end
end

summaryTable = cell2table(rows, 'VariableNames', ...
    {'LoadID','ScenarioName','Policy','AP','Role','ValidP95Runs', ...
     'MeanP95','CI_Low','CI_High','MeanGoodput', ...
     'MinCompletedWindow','MeanUnfinished','MaxUnfinished', ...
     'MeanOutstandingAtWarmup','MeanCtrlAirtime'});

writetable(summaryTable, fullfile(analysisDir, 'hotspot_summary.csv'));

% Plot overall metrics and hotspot-role metrics.
f = figure('Color', 'w', 'Position', [80 80 1600 950]);
ax = gobjects(6,1);
roles = ["Overall", "Hotspot", "Hotspot", ...
         "Overall", "Overall", "Hotspot"];
fields = ["MeanP95", "MeanP95", "MeanGoodput", ...
          "MeanCtrlAirtime", "MeanUnfinished", "MeanUnfinished"];
titles = {'Overall P95', 'Hotspot P95', 'Hotspot goodput', ...
    'Coordination airtime', 'Overall unfinished packets', ...
    'Hotspot unfinished packets'};
yLabels = {'Mean run P95 (time units)', ...
    'Mean run P95 (time units)', 'Goodput (bits/time unit)', ...
    'Control airtime (%)', 'Mean unfinished packets', ...
    'Mean unfinished packets'};

for panel = 1:6
    col = mod(panel-1, 3);
    row = floor((panel-1)/3);
    ax(panel) = axes('Parent', f, 'Position', ...
        [0.075+col*0.32, 0.085+(1-row)*0.495, 0.24, 0.355], ...
        'FontName', 'Arial', 'FontSize', 10, ...
        'Box', 'on', 'TickDir', 'out');
    hold(ax(panel), 'on')
    grid(ax(panel), 'on')

    for p = 1:3
        S = summaryTable(summaryTable.Policy == policies(p) & ...
            summaryTable.Role == roles(panel), :);
        S = sortrows(S, 'LoadID');
        y = S.(char(fields(panel)));

        if panel <= 2
            errorbar(ax(panel), 1:2, y, ...
                y-S.CI_Low, S.CI_High-y, ...
                'Color', colors(p,:), 'LineStyle', styles{p}, ...
                'Marker', markers{p}, 'LineWidth', 1.4, ...
                'CapSize', 8, 'DisplayName', labels{p});
        else
            if panel == 4
                y = 100*y;
            end
            plot(ax(panel), 1:2, y, ...
                'Color', colors(p,:), 'LineStyle', styles{p}, ...
                'Marker', markers{p}, 'LineWidth', 1.4, ...
                'DisplayName', labels{p});
        end
    end

    title(ax(panel), titles{panel}, 'FontSize', 11)
    ylabel(ax(panel), yLabels{panel})
    xlim(ax(panel), [0.8 2.2])
    xticks(ax(panel), [1 2])
    xticklabels(ax(panel), {'Centre hotspot', 'Endpoint hotspot'})
    legend(ax(panel), 'Location', 'best', 'FontSize', 9)
    ylim(ax(panel), 'padded')
end

% Show the configured hotspot payload rate on a zero-based scale.
hotspotRate = max([M.LambdaAP1; M.LambdaAP2; M.LambdaAP3]);
offered = hotspotRate * settings.base.packetBits;
yline(ax(3), offered, 'k-.', 'DisplayName', 'Hotspot offered rate');
hotspotRows = summaryTable.Role == "Hotspot";
upper = max([offered; summaryTable.MeanGoodput(hotspotRows)]);
ylim(ax(3), [0 ceil(1.1*upper/100)*100]);

% Export the full figure canvas with outer margins.
drawnow
set(f, 'PaperPositionMode', 'auto', 'PaperUnits', 'inches');
paperPosition = get(f, 'PaperPosition');
set(f, 'PaperSize', paperPosition(3:4));

print(f, fullfile(analysisDir, 'hotspot_results.png'), '-dpng', '-r300');
print(f, fullfile(analysisDir, 'hotspot_results.pdf'), '-dpdf', '-painters');
savefig(f, fullfile(analysisDir, 'hotspot_results.fig'));

disp(summaryTable(summaryTable.Role ~= "Non-hotspot", :))
fprintf('Analysis outputs: %s\n', analysisDir)
