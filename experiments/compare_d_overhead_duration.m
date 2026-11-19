clear; clc;

% Compare existing batches without rerunning the simulation.
wifi8Root = fileparts(fileparts(mfilename('fullpath')));
rootDir = fullfile(wifi8Root, 'results');
batchDirs = {
    fullfile(rootDir, 'D_overhead_refine_20261118_010109')
    fullfile(rootDir, 'D_overhead_long_20261118_012128')
};
horizons = [10000 20000];
loads = [0.15 0.30 0.45];
ratios = [1.6 1.7 1.8 1.9 2.0 2.1];
policies = ["rr" "queue"];
required = {'AP','TotalLambda','CtrlRatio','Policy','Repeat', ...
    'P95','Goodput','Unfinished','OutstandingAtWarmup', ...
    'OutstandingAtMidpoint','MeasureTime'};
rows = cell(0, 13);

for b = 1:2
    csvPath = fullfile(batchDirs{b}, 'run_metrics.csv');
    assert(isfile(csvPath), 'Missing input: %s', csvPath);
    T = readtable(csvPath, 'TextType', 'string');
    assert(all(ismember(required, T.Properties.VariableNames)), ...
        'Required columns are missing in %s', csvPath);
    T = T(T.AP == 0, :);

    for k = 1:numel(loads)
        for p = 1:numel(policies)
            for j = 1:numel(ratios)
                S = T(abs(T.TotalLambda-loads(k)) < 1e-8 & ...
                    abs(T.CtrlRatio-ratios(j)) < 1e-8 & ...
                    T.Policy == policies(p), :);
                assert(height(S) == 20 && numel(unique(S.Repeat)) == 20, ...
                    'Expected 20 distinct repeats: batch %d, load %.2f, %s, ratio %.1f', ...
                    b, loads(k), char(policies(p)), ratios(j));
                values = S{:, {'P95','Goodput','Unfinished', ...
                    'OutstandingAtWarmup','OutstandingAtMidpoint','MeasureTime'}};
                assert(all(isfinite(values), 'all') && all(S.MeasureTime > 0), ...
                    'Nonfinite values or invalid measurement duration.');
                assert(all(abs(S.MeasureTime - 0.9*horizons(b)) < 1e-8), ...
                    'Unexpected measurement duration.');

                % Rates allow comparison across different window lengths.
                delta = S.Unfinished - S.OutstandingAtWarmup;
                fullRate = delta ./ S.MeasureTime;
                halfRate = (S.Unfinished-S.OutstandingAtMidpoint) ...
                    ./ (S.MeasureTime/2);
                rows(end+1,:) = {horizons(b), loads(k), ratios(j), ...
                    policies(p), height(S), mean(S.P95), mean(S.Goodput), ...
                    mean(S.Unfinished), mean(delta), mean(fullRate), ...
                    mean(halfRate), nnz(halfRate > 0), mean(S.OutstandingAtWarmup)};
            end
        end
    end
end

R = cell2table(rows, 'VariableNames', {'Tsim','TotalLambda','CtrlRatio', ...
    'Policy','Runs','MeanRunP95','MeanGoodput','MeanUnfinished', ...
    'MeanBacklogChange','MeanBacklogGrowthRate','MeanSecondHalfGrowthRate', ...
    'RunsWithSecondHalfGrowth','MeanWarmupBacklog'});
outDir = fullfile(wifi8Root, 'results', ...
    ['duration_check_' datestr(now, 'yyyymmdd_HHMMSS')]);
mkdir(outDir);
writetable(R, fullfile(outDir, 'duration_comparison.csv'));

% Colors identify policies; line styles identify simulation horizons.
colors = [0 0.45 0.70; 0.90 0.35 0];
styles = {'--','-'};
markers = {'s','^'};
metrics = {'MeanRunP95','MeanUnfinished', ...
    'MeanSecondHalfGrowthRate','MeanGoodput'};
titles = {'Mean per-run P95','End-of-run unfinished packets', ...
    'Backlog growth during second half','Aggregate goodput'};
labels = {'P95 (time units)','Packets','Packets / time unit', ...
    'Goodput (bits / time unit)'};

for k = 1:numel(loads)
    f = figure('Visible','off','Color','w','Position',[80 80 1400 900]);
    layout = tiledlayout(f,2,2,'TileSpacing','loose','Padding','loose');
    for m = 1:4
        ax = nexttile(layout); hold(ax,'on');
        for p = 1:2
            for b = 1:2
                S = R(abs(R.TotalLambda-loads(k)) < 1e-8 & ...
                    R.Policy == policies(p) & R.Tsim == horizons(b), :);
                S = sortrows(S, 'CtrlRatio');
                plot(ax,S.CtrlRatio,S.(metrics{m}), ...
                    'Color',colors(p,:),'LineStyle',styles{b}, ...
                    'Marker',markers{p},'LineWidth',1.7,'MarkerSize',6, ...
                    'DisplayName',sprintf('%s, T=%d',char(policies(p)),horizons(b)));
            end
        end
        if m == 3
            yline(ax,0,':','Color',[0.3 0.3 0.3],'HandleVisibility','off');
        end
        grid(ax,'on'); box(ax,'on');
        xlim(ax,[1.55 2.15]); xticks(ax,ratios); ylim(ax,'padded');
        xlabel(ax,'Control-to-data time ratio'); ylabel(ax,labels{m});
        title(ax,titles{m});
        legend(ax,'Location','best','FontSize',9);
        set(ax,'FontSize',11);
    end
    title(layout,sprintf('Duration sensitivity | Total arrival rate %.2f',loads(k)));
    stem = fullfile(outDir,sprintf('duration_load_%02d',k));
    savefig(f,[stem '.fig']);
    exportgraphics(f,[stem '.png'],'Resolution',200);
    exportgraphics(f,[stem '.pdf'],'ContentType','vector');
    close(f);
end

disp(R(abs(R.TotalLambda-0.45) < 1e-8, ...
    {'Tsim','CtrlRatio','Policy','MeanRunP95','MeanUnfinished', ...
    'MeanSecondHalfGrowthRate','RunsWithSecondHalfGrowth'}));
fprintf('\nSaved duration comparison to:\n%s\n',outDir);
fprintf('This is a horizon sensitivity comparison, not a paired-path extension.\n');
fprintf('Near-zero average backlog growth alone does not establish stationarity.\n');
