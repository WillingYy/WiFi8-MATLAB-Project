clear; clc;

% Read the final long-horizon paired comparison.
wifi8Root = fileparts(fileparts(mfilename('fullpath')));

analysisDir = fullfile(wifi8Root, 'results', ...
    'D_overhead_long_20261118_012128', ...
    'analysis_20261118_013651');

inputFile = fullfile(analysisDir, 'overhead_paired_gain.csv');
assert(isfile(inputFile), 'Input CSV not found: %s', inputFile);

T = readtable(inputFile, 'TextType', 'string');

% Select the network-level results at total arrival rate 0.30.
T = T(abs(T.TotalLambda - 0.30) < 1e-8 & T.AP == 0, :);

policies = ["rr", "queue"];
policyNames = {'Round-robin', 'Queue-aware'};
colors = [0.00 0.45 0.70; 0.90 0.35 0.00];
lineStyles = {'-', '--'};
markers = {'s', '^'};

% Save outputs beside this script.
outDir = fullfile(wifi8Root, 'results', 'paired_gain_030');
if ~isfolder(outDir)
    mkdir(outDir);
end

f = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100 100 1000 680]);

ax = axes(f, 'Position', [0.13 0.15 0.82 0.72]);
hold(ax, 'on');

for p = 1:2
    S = T(T.Policy == policies(p), :);
    S = sortrows(S, 'CtrlRatio');

    assert(height(S) == 6 && all(S.ValidPairs == 20), ...
        'Expected six settings with 20 valid pairs per policy.');

    x = S.CtrlRatio;
    y = S.MeanRandomMinusCoord;
    low = S.CI_Low;
    high = S.CI_High;

    assert(all(isfinite([x; y; low; high])), ...
        'Nonfinite values found.');
    assert(all(low <= y & y <= high), ...
        'The interval does not contain its point estimate.');

    errorbar(ax, x, y, y-low, high-y, ...
        'Color', colors(p,:), ...
        'LineStyle', lineStyles{p}, ...
        'Marker', markers{p}, ...
        'MarkerFaceColor', 'w', ...
        'MarkerSize', 8, ...
        'LineWidth', 1.8, ...
        'CapSize', 10, ...
        'DisplayName', policyNames{p});
end

% Positive gain favours coordination.
yline(ax, 0, ':', 'Zero gain', ...
    'Color', [0.30 0.30 0.30], ...
    'LineWidth', 1.3, ...
    'LabelHorizontalAlignment', 'left', ...
    'HandleVisibility', 'off');

xlabel(ax, 'Control-to-data time ratio');
ylabel(ax, 'Random P95 minus coordinated P95 (time units)');

title(ax, { ...
    'Paired P95 gain with pointwise 95% bootstrap intervals', ...
    'Total arrival rate 0.30 | 20 replications | Tsim = 20000'}, ...
    'FontSize', 13);

xlim(ax, [1.55 2.15]);
xticks(ax, [1.6 1.7 1.8 1.9 2.0 2.1]);
ylim(ax, 'padded');

grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 12);
legend(ax, 'Location', 'northeast', 'FontSize', 11);

savefig(f, fullfile(outDir, 'paired_gain_030.fig'));
exportgraphics(f, fullfile(outDir, 'paired_gain_030.png'), ...
    'Resolution', 300);
exportgraphics(f, fullfile(outDir, 'paired_gain_030.pdf'), ...
    'ContentType', 'vector');
close(f);

% Save the exact rows used in the figure.
T = sortrows(T, {'Policy', 'CtrlRatio'});
writetable(T, fullfile(outDir, 'paired_gain_030_data.csv'));

fprintf('Saved figure and data to:\n%s\n', outDir);
disp(T(:, {'Policy','CtrlRatio','MeanRandomMinusCoord', ...
    'CI_Low','CI_High','Status'}));
