clear
close all

batchDir = fullfile('results', 'D_load_20261117_233652');
T = readtable(fullfile(batchDir, 'run_metrics.csv'));
T.Policy = string(T.Policy);
G = T(T.AP == 0, :);

loads = [0.15 0.30 0.45];
policies = ["random", "rr", "queue"];
nBootstrap = 5000;

bsStream = RandStream('mt19937ar', 'Seed', 30001);

meanP95 = zeros(3,3);
lowP95 = zeros(3,3);
highP95 = zeros(3,3);
meanGoodput = zeros(3,3);
meanOutstanding = zeros(3,3,3);

rows = cell(0,12);

for k = 1:3
    for p = 1:3
        S = G(G.LoadID == k & G.Policy == policies(p), :);
        S = sortrows(S, 'Repeat');

        assert(height(S) == 20)
        assert(isequal(S.Repeat, (1:20)'))
        assert(all(isfinite(S.P95)))

        x = S.P95;
        idx = randi(bsStream, numel(x), numel(x), nBootstrap);
        bootMeans = mean(x(idx), 1);

        meanP95(k,p) = mean(x);
        lowP95(k,p) = my_quantile(bootMeans, 0.025);
        highP95(k,p) = my_quantile(bootMeans, 0.975);
        meanGoodput(k,p) = mean(S.Goodput);

        meanOutstanding(k,p,:) = reshape( ...
            [mean(S.OutstandingAtWarmup), ...
             mean(S.OutstandingAtMidpoint), ...
             mean(S.Unfinished)], 1, 1, 3);

        rows(end+1,:) = {loads(k), policies(p), height(S), ...
            meanP95(k,p), lowP95(k,p), highP95(k,p), ...
            meanGoodput(k,p), mean(S.NCompletedWindow), ...
            min(S.NCompletedWindow), mean(S.Unfinished), ...
            max(S.Unfinished), mean(S.CtrlAirtime)};
    end
end

summaryTable = cell2table(rows, 'VariableNames', ...
    {'TotalLambda','Policy','Runs','MeanP95','P95_CI_Low', ...
     'P95_CI_High','MeanGoodput','MeanCompletedWindow', ...
     'MinCompletedWindow','MeanUnfinished','MaxUnfinished', ...
     'MeanCtrlAirtime'});

disp(summaryTable)
writetable(summaryTable, fullfile(batchDir, 'load_summary.csv'))

% Create a figure with explicit outer margins and panel spacing.
f = figure('Color', 'w', ...
    'Units', 'pixels', ...
    'Position', [80 80 1600 1000]);

colors = lines(3);
markers = {'o', 's', '^'};
lineStyles = {'-', '--', ':'};
labels = {'Random access', 'Round-robin', 'Queue-aware'};

leftMargin = 0.075;
rightMargin = 0.035;
bottomMargin = 0.085;
topMargin = 0.065;
columnGap = 0.080;
rowGap = 0.140;

panelWidth = (1-leftMargin-rightMargin-2*columnGap)/3;
panelHeight = (1-bottomMargin-topMargin-rowGap)/2;

ax = gobjects(6,1);

for panel = 1:6
    column = mod(panel-1, 3);
    row = floor((panel-1)/3);

    x = leftMargin + column*(panelWidth+columnGap);
    y = bottomMargin + (1-row)*(panelHeight+rowGap);

    ax(panel) = axes('Parent', f, ...
        'Units', 'normalized', ...
        'Position', [x y panelWidth panelHeight], ...
        'FontName', 'Arial', ...
        'FontSize', 10, ...
        'LineWidth', 0.8, ...
        'Box', 'on', ...
        'TickDir', 'out');

    hold(ax(panel), 'on');
    grid(ax(panel), 'on');
    ax(panel).GridAlpha = 0.15;
end

% Plot the mean run P95 and its 95% bootstrap confidence interval.
for p = 1:3
    errorbar(ax(1), loads, meanP95(:,p), ...
        meanP95(:,p)-lowP95(:,p), ...
        highP95(:,p)-meanP95(:,p), ...
        'Color', colors(p,:), ...
        'LineStyle', lineStyles{p}, ...
        'Marker', markers{p}, ...
        'MarkerSize', 6, ...
        'LineWidth', 1.4, ...
        'CapSize', 8, ...
        'DisplayName', labels{p});
end

xlabel(ax(1), 'Total arrival rate');
ylabel(ax(1), 'Mean run P95 (time units)');
title(ax(1), {'Overall P95', '95% bootstrap confidence intervals'}, ...
    'FontSize', 11);
xlim(ax(1), [0.12 0.48]);
xticks(ax(1), loads);
ylim(ax(1), [0 max(highP95(:))*1.18]);
legend(ax(1), 'Location', 'northwest', 'FontSize', 9);

% Show the coordinated policies on a separate vertical scale.
for p = 2:3
    errorbar(ax(2), loads, meanP95(:,p), ...
        meanP95(:,p)-lowP95(:,p), ...
        highP95(:,p)-meanP95(:,p), ...
        'Color', colors(p,:), ...
        'LineStyle', lineStyles{p}, ...
        'Marker', markers{p}, ...
        'MarkerSize', 6, ...
        'LineWidth', 1.4, ...
        'CapSize', 8, ...
        'DisplayName', labels{p});
end

xlabel(ax(2), 'Total arrival rate');
ylabel(ax(2), 'Mean run P95 (time units)');
title(ax(2), {'Coordinated policies', ...
    '95% bootstrap confidence intervals'}, 'FontSize', 11);
xlim(ax(2), [0.12 0.48]);
xticks(ax(2), loads);

coordinatedLow = lowP95(:,2:3);
coordinatedHigh = highP95(:,2:3);
lowerBound = min(coordinatedLow(:));
upperBound = max(coordinatedHigh(:));
padding = max(0.1, 0.15*(upperBound-lowerBound));
ylim(ax(2), [max(0, lowerBound-padding), upperBound+padding]);
legend(ax(2), 'Location', 'northwest', 'FontSize', 9);

% Compare delivered payload with the configured offered payload rate.
for p = 1:3
    plot(ax(3), loads, meanGoodput(:,p), ...
        'Color', colors(p,:), ...
        'LineStyle', lineStyles{p}, ...
        'Marker', markers{p}, ...
        'MarkerSize', 6, ...
        'LineWidth', 1.4, ...
        'DisplayName', labels{p});
end

plot(ax(3), loads, loads*12000, 'k-.', ...
    'LineWidth', 1.1, ...
    'DisplayName', 'Offered payload rate');

xlabel(ax(3), 'Total arrival rate');
ylabel(ax(3), 'Goodput (bits/time unit)');
title(ax(3), 'Aggregate goodput', 'FontSize', 11);
xlim(ax(3), [0.12 0.48]);
xticks(ax(3), loads);
ylim(ax(3), [0 max([meanGoodput(:); loads(:)*12000])*1.15]);
legend(ax(3), 'Location', 'northwest', 'FontSize', 9);

% Read checkpoint times from a saved run.
sample = load(fullfile(batchDir, ...
    'load_01_rep_01_random.mat'), 'checkpoint');
times = sample.checkpoint([1 3 5]);

% Display the mean outstanding packet count at three checkpoints.
for k = 1:3
    panel = k+3;

    for p = 1:3
        y = reshape(meanOutstanding(k,p,:), 1, 3);
        plot(ax(panel), times, y, ...
            'Color', colors(p,:), ...
            'LineStyle', lineStyles{p}, ...
            'Marker', markers{p}, ...
            'MarkerSize', 6, ...
            'LineWidth', 1.4, ...
            'DisplayName', labels{p});
    end

    xlabel(ax(panel), 'Simulation time');
    ylabel(ax(panel), 'Mean outstanding packets');
    title(ax(panel), sprintf('Backlog at total rate %.2f', loads(k)), ...
        'FontSize', 11);

    timePadding = 0.08*(times(end)-times(1));
    xlim(ax(panel), ...
        [times(1)-timePadding, times(end)+timePadding]);
    xticks(ax(panel), times);

    values = meanOutstanding(k,:,:);
    ylim(ax(panel), [0 max(0.2, max(values(:))*1.25)]);
    legend(ax(panel), 'Location', 'best', 'FontSize', 9);
end

% Export the full figure canvas to preserve the outer margins.
drawnow;
set(f, 'PaperPositionMode', 'auto');
set(f, 'PaperUnits', 'inches');
paperPosition = get(f, 'PaperPosition');
set(f, 'PaperSize', paperPosition(3:4));

print(f, fullfile(batchDir, 'load_diagnostics.png'), ...
    '-dpng', '-r300');
print(f, fullfile(batchDir, 'load_diagnostics.pdf'), ...
    '-dpdf', '-painters');
savefig(f, fullfile(batchDir, 'load_diagnostics.fig'));

fprintf('Saved revised figures to %s\n', batchDir);