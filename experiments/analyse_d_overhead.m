clear
close all

% Select the completed overhead or refined overhead batch.
batchDir = uigetdir(fullfile(pwd, 'results'), ...
    'Select the overhead experiment batch');
if isequal(batchDir, 0)
    return
end

T = readtable(fullfile(batchDir, 'run_metrics.csv'));
T.Policy = string(T.Policy);

settings = load(fullfile(batchDir, 'batch_config.mat'), ...
    'base', 'nRep', 'loads', 'ctrlRatios');

loads = settings.loads;
ratios = settings.ctrlRatios;
nRep = settings.nRep;
nLoads = numel(loads);
nRatios = numel(ratios);

% Use contrasting colors, markers, and line styles.
policies = ["rr", "queue"];
labels = {'Round-robin', 'Queue-aware'};
colors = [0.00 0.45 0.70; 0.90 0.35 0.00];
markers = {'s', '^'};
styles = {'-', '--'};

% Create a separate analysis directory.
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
analysisDir = fullfile(batchDir, ['analysis_' stamp]);
mkdir(analysisDir)

% Configure reproducible paired bootstrap resampling.
bsStream = RandStream('mt19937ar', 'Seed', 30006);
nBootstrap = 5000;

p95Mean = nan(nLoads, nRatios, 2);
gainMean = nan(nLoads, nRatios, 2);
gainLow = nan(nLoads, nRatios, 2);
gainHigh = nan(nLoads, nRatios, 2);
ctrlMean = nan(nLoads, nRatios, 2);
goodputMean = nan(nLoads, nRatios, 2);
backlogMean = nan(nLoads, nRatios, 2);
backlogChange = nan(nLoads, nRatios, 2);

baselineP95 = nan(nLoads, 1);
baselineGoodput = nan(nLoads, 1);
baselineBacklog = nan(nLoads, 1);

summaryRows = cell(0, 15);
gainRows = cell(0, 10);
crossingRows = cell(0, 6);

for k = 1:nLoads
    % Reuse bootstrap indices across policies and overhead settings.
    idx = randi(bsStream, nRep, nRep, nBootstrap);

    for ap = 0:3
        selected = T.LoadID == k & ...
            T.Policy == "random" & T.AP == ap;
        B = sortrows(T(selected, :), 'Repeat');

        assert(height(B) == nRep)
        assert(isequal(B.Repeat, (1:nRep)'))

        [bm, bl, bh, bn] = bootstrap_mean_ci(B.P95, idx);

        summaryRows(end+1,:) = { ...
            k, loads(k), NaN, "random", ap, bn, bm, bl, bh, ...
            mean(B.Goodput), mean(B.CtrlAirtime), ...
            mean(B.Unfinished), max(B.Unfinished), ...
            min(B.NCompletedWindow), ...
            mean(B.Unfinished-B.OutstandingAtWarmup)};

        if ap == 0
            baselineP95(k) = bm;
            baselineGoodput(k) = mean(B.Goodput);
            baselineBacklog(k) = mean(B.Unfinished);
        end

        for j = 1:nRatios
            for p = 1:numel(policies)
                selected = T.LoadID == k & ...
                    T.Policy == policies(p) & ...
                    T.AP == ap & ...
                    abs(T.CtrlRatio-ratios(j)) < 1e-12;

                S = sortrows(T(selected, :), 'Repeat');

                % Verify replication IDs, seeds, and arrival counts.
                assert(height(S) == nRep)
                assert(isequal(S.Repeat, B.Repeat))
                assert(isequal(S.SeedArrival, B.SeedArrival))
                assert(isequal(S.SeedAccess, B.SeedAccess))
                assert(isequal(S.NArrived, B.NArrived))

                [m, lo, hi, nv] = bootstrap_mean_ci(S.P95, idx);

                summaryRows(end+1,:) = { ...
                    k, loads(k), ratios(j), policies(p), ap, nv, ...
                    m, lo, hi, mean(S.Goodput), ...
                    mean(S.CtrlAirtime), mean(S.Unfinished), ...
                    max(S.Unfinished), min(S.NCompletedWindow), ...
                    mean(S.Unfinished-S.OutstandingAtWarmup)};

                % Positive differences indicate lower coordinated P95.
                difference = B.P95-S.P95;
                [gm, gl, gh, ng] = bootstrap_mean_ci(difference, idx);

                status = "Undefined";
                if ng == nRep
                    status = "Uncertain";
                    if gl > 0
                        status = "Benefit";
                    elseif gh < 0
                        status = "Penalty";
                    end
                end

                gainRows(end+1,:) = { ...
                    k, loads(k), ratios(j), policies(p), ap, ng, ...
                    gm, gl, gh, status};

                if ap == 0
                    p95Mean(k,j,p) = m;
                    gainMean(k,j,p) = gm;
                    gainLow(k,j,p) = gl;
                    gainHigh(k,j,p) = gh;
                    ctrlMean(k,j,p) = mean(S.CtrlAirtime);
                    goodputMean(k,j,p) = mean(S.Goodput);
                    backlogMean(k,j,p) = mean(S.Unfinished);
                    backlogChange(k,j,p) = ...
                        mean(S.Unfinished-S.OutstandingAtWarmup);
                end
            end
        end
    end

    % Record all observed mean-gain crossings.
    for p = 1:numel(policies)
        for j = 1:nRatios-1
            leftGain = gainMean(k,j,p);
            rightGain = gainMean(k,j+1,p);

            if isfinite(leftGain) && isfinite(rightGain) && ...
                    (leftGain*rightGain < 0 || ...
                     leftGain == 0 || rightGain == 0)

                crossingRows(end+1,:) = { ...
                    loads(k), policies(p), ratios(j), ratios(j+1), ...
                    leftGain, rightGain};
            end
        end
    end
end

% Save network-level and per-AP statistics.
summaryTable = cell2table(summaryRows, 'VariableNames', ...
    {'LoadID','TotalLambda','CtrlRatio','Policy','AP','ValidP95Runs', ...
     'MeanP95','CI_Low','CI_High','MeanGoodput','MeanCtrlAirtime', ...
     'MeanUnfinished','MaxUnfinished','MinCompletedWindow', ...
     'MeanBacklogChange'});

gainTable = cell2table(gainRows, 'VariableNames', ...
    {'LoadID','TotalLambda','CtrlRatio','Policy','AP','ValidPairs', ...
     'MeanRandomMinusCoord','CI_Low','CI_High','Status'});

crossingTable = cell2table(crossingRows, 'VariableNames', ...
    {'TotalLambda','Policy','RatioLeft','RatioRight', ...
     'GainLeft','GainRight'});

writetable(summaryTable, ...
    fullfile(analysisDir, 'overhead_summary.csv'));
writetable(gainTable, ...
    fullfile(analysisDir, 'overhead_paired_gain.csv'));
writetable(crossingTable, ...
    fullfile(analysisDir, 'crossing_candidates.csv'));

% Generate and export one background figure per offered load.
for k = 1:nLoads
    figHandle = figure( ...
        'Color', 'w', ...
        'Position', [80 80 1600 1000], ...
        'Visible', 'off');

    ax = gobjects(6,1);

    for panel = 1:6
        column = mod(panel-1, 3);
        row = floor((panel-1)/3);

        ax(panel) = axes('Parent', figHandle, 'Position', ...
            [0.075+column*0.32, 0.085+(1-row)*0.495, 0.24, 0.355], ...
            'FontName', 'Arial', 'FontSize', 10, ...
            'Box', 'on', 'TickDir', 'out');

        hold(ax(panel), 'on')
        grid(ax(panel), 'on')
        ax(panel).GridAlpha = 0.15;

        xlabel(ax(panel), 'Control-to-data time ratio')
        xlim(ax(panel), [min(ratios)-0.1 max(ratios)+0.1])
    end

    for p = 1:numel(policies)
        % Apply consistent policy styles across all panels.
        lineOptions = { ...
            'Color', colors(p,:), ...
            'LineStyle', styles{p}, ...
            'Marker', markers{p}, ...
            'MarkerSize', 6, ...
            'LineWidth', 1.5, ...
            'DisplayName', labels{p}};

        plot(ax(1), ratios, ...
            reshape(p95Mean(k,:,p), 1, []), lineOptions{:});

        g = reshape(gainMean(k,:,p), 1, []);
        lo = reshape(gainLow(k,:,p), 1, []);
        hi = reshape(gainHigh(k,:,p), 1, []);

        errorbar(ax(2), ratios, g, g-lo, hi-g, ...
            lineOptions{:}, 'CapSize', 6);

        plot(ax(3), ratios, ...
            100*reshape(ctrlMean(k,:,p), 1, []), lineOptions{:});

        plot(ax(4), ratios, ...
            reshape(goodputMean(k,:,p), 1, []), lineOptions{:});

        plot(ax(5), ratios, ...
            reshape(backlogMean(k,:,p), 1, []), lineOptions{:});

        plot(ax(6), ratios, ...
            reshape(backlogChange(k,:,p), 1, []), lineOptions{:});
    end

    % Add random-access baselines and zero-gain references.
    yline(ax(1), baselineP95(k), 'k-.', ...
        'LineWidth', 1.2, 'DisplayName', 'Random access');

    yline(ax(2), 0, 'k:', ...
        'LineWidth', 1.1, 'HandleVisibility', 'off');

    yline(ax(4), baselineGoodput(k), 'k-.', ...
        'LineWidth', 1.2, 'DisplayName', 'Random access');

    offered = loads(k)*settings.base.packetBits;
    yline(ax(4), offered, ':', ...
        'Color', [0.45 0.45 0.45], ...
        'LineWidth', 1.2, 'DisplayName', 'Offered payload rate');

    yline(ax(5), baselineBacklog(k), 'k-.', ...
        'LineWidth', 1.2, 'DisplayName', 'Random access');

    yline(ax(6), 0, 'k:', ...
        'LineWidth', 1.1, 'HandleVisibility', 'off');

    titles = { ...
        'Overall P95', ...
        'Paired P95 gain with 95% CI', ...
        'Coordination airtime', ...
        'Aggregate goodput', ...
        'End-of-run unfinished packets', ...
        'Backlog change since warm-up'};

    yLabels = { ...
        'Mean run P95 (time units)', ...
        'Random P95 minus coordinated P95', ...
        'Control airtime (%)', ...
        'Goodput (bits/time unit)', ...
        'Mean unfinished packets', ...
        'Mean outstanding packet change'};

    for panel = 1:6
        title(ax(panel), ...
            {titles{panel}, ...
             sprintf('Total arrival rate %.2f', loads(k))}, ...
            'FontSize', 11);

        ylabel(ax(panel), yLabels{panel})
        legend(ax(panel), 'Location', 'best', 'FontSize', 8)
        ylim(ax(panel), 'padded')
    end

    % Use a zero-based goodput axis.
    values = reshape(goodputMean(k,:,:), [], 1);
    ymax = max([offered; baselineGoodput(k); values]);
    ylim(ax(4), [0 1.1*ymax]);

    % Save the editable figure before exporting PNG and PDF.
    drawnow
    assert(isgraphics(figHandle, 'figure'), ...
        'The figure handle became invalid before export.');

    name = sprintf('overhead_load_%02d', k);

    set(figHandle, ...
        'PaperPositionMode', 'auto', 'PaperUnits', 'inches');
    paperPosition = get(figHandle, 'PaperPosition');
    set(figHandle, 'PaperSize', paperPosition(3:4));

    savefig(figHandle, fullfile(analysisDir, [name '.fig']));

    print(figHandle, fullfile(analysisDir, [name '.png']), ...
        '-dpng', '-r300');

    print(figHandle, fullfile(analysisDir, [name '.pdf']), ...
        '-dpdf', '-painters');

    % Close the background figure after all exports complete.
    close(figHandle);

    fprintf('Exported figure %d/%d.\n', k, nLoads)
end

disp(gainTable(gainTable.AP == 0, :))
disp(crossingTable)

fprintf('Analysis outputs: %s\n', analysisDir)
winopen(analysisDir)


function [estimate, lower, upper, validCount] = bootstrap_mean_ci(x, idx)
% Estimate a mean and percentile bootstrap interval using complete runs.
    validCount = nnz(isfinite(x));
    estimate = NaN;
    lower = NaN;
    upper = NaN;

    if validCount == numel(x)
        bootstrapMeans = mean(x(idx), 1);
        estimate = mean(x);
        lower = my_quantile(bootstrapMeans, 0.025);
        upper = my_quantile(bootstrapMeans, 0.975);
    end
end