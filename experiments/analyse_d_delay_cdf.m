clear; clc;

% Read existing runs; do not rerun the simulation.
wifi8Root = fileparts(fileparts(mfilename('fullpath')));
batchDir = fullfile(wifi8Root, 'results', 'D_load_20261117_233652');
outDir = fullfile(wifi8Root, 'results', ...
    ['cdf_analysis_' datestr(now,'yyyymmdd_HHMMSS')]);
T = readtable(fullfile(batchDir,'run_metrics.csv'),'TextType','string');
loads = [0.15 0.30 0.45];
policies = ["random" "rr" "queue"];
names = {'Random access','Round-robin','Queue-aware'};
colors = [0.20 0.20 0.20; 0 0.45 0.70; 0.90 0.35 0];
styles = {':','-','--'};
rows = cell(0,10);
mkdir(outDir);

for k = 1:numel(loads)
    pooled = cell(3,4);
    runP95 = nan(20,3,4);
    unfinished = nan(20,3,4);
    for p = 1:3
        for rep = 1:20
            file = fullfile(batchDir,sprintf('load_%02d_rep_%02d_%s.mat', ...
                k,rep,char(policies(p))));
            assert(isfile(file),'Missing run: %s',file);
            S = load(file,'cfg','r');
            cfg = S.cfg; r = S.r;
            assert(strcmp(cfg.policy,char(policies(p))));
            assert(abs(sum(cfg.lambda)-loads(k)) < 1e-8);
            assert(abs(cfg.Tctrl/cfg.Tdata-0.1) < 1e-8);
            assert(r.conservation.balanced && cfg.numAPs == 3);
            byAP = cell(1,3);
            for ap = 1:3
                ct = r.completions.completionTime{ap}(:);
                at = r.completions.arrivalTime{ap}(:);
                assert(numel(ct) == numel(at));
                keep = ct >= cfg.Twarmup & ct <= cfg.Tsim;
                d = ct(keep)-at(keep);
                assert(~isempty(d) && all(isfinite(d)) && all(d >= 0));
                byAP{ap} = d;
            end
            allD = vertcat(byAP{:});
            for a = 0:3
                if a == 0
                    d = allD;
                    u = r.conservation.unfinished;
                else
                    d = byAP{a};
                    u = r.perAP(a).unfinished;
                end
                q = local_quantile(d,0.95);
                V = T(T.LoadID == k & T.Repeat == rep & ...
                    T.Policy == policies(p) & T.AP == a,:);
                assert(height(V) == 1,'Missing or duplicate metrics row.');
                assert(numel(d) == V.NCompletedWindow && u == V.Unfinished);
                assert(abs(q-V.P95) <= 1e-8*max(1,abs(q)), ...
                    'P95 mismatch: load %d, repeat %d, policy %s, AP %d', ...
                    k,rep,char(policies(p)),a);
                pooled{p,a+1} = [pooled{p,a+1}; d];
                runP95(rep,p,a+1) = q;
                unfinished(rep,p,a+1) = u;
            end
        end
        for a = 0:3
            d = pooled{p,a+1};
            rows(end+1,:) = {loads(k),policies(p),a,20,numel(d), ...
                local_quantile(d,0.50),local_quantile(d,0.95), ...
                local_quantile(d,0.99),mean(runP95(:,p,a+1)), ...
                mean(unfinished(:,p,a+1))};
        end
    end

    % Pool completed packets across runs for descriptive CDFs.
    % This weights runs by their number of completed-window packets.
    f = figure('Visible','off','Color','w','Position',[80 80 1450 620]);
    lay = tiledlayout(f,1,2,'Padding','loose','TileSpacing','loose');
    xmax = max(cellfun(@max,pooled(:,1)));
    for panel = 1:2
        ax = nexttile(lay); hold(ax,'on');
        for p = 1:3
            d = sort(pooled{p,1});
            [x,~,group] = unique(d);
            counts = accumarray(group,1);
            y = cumsum(counts)/numel(d);
            stairs(ax,[0;x],[0;y],'Color',colors(p,:), ...
                'LineStyle',styles{p},'LineWidth',2,'DisplayName',names{p});
        end
        xlim(ax,[0 1.03*xmax]);
        if panel == 1
            ylim(ax,[0 1.01]); title(ax,'Completed-packet delay CDF');
        else
            ylim(ax,[0.90 1.001]); title(ax,'Tail detail: CDF from 0.90 to 1');
        end
        yline(ax,0.95,'-.','95%','Color',[0.5 0.5 0.5], ...
            'HandleVisibility','off');
        xlabel(ax,'Enqueue-to-completion delay (time units)');
        ylabel(ax,'Empirical cumulative probability');
        grid(ax,'on'); box(ax,'on'); set(ax,'FontSize',11);
        legend(ax,'Location','southeast','FontSize',10);
    end
    title(lay,sprintf('Total arrival rate %.2f | Control/data = 0.10 | 20 runs per policy',loads(k)));
    stem = fullfile(outDir,sprintf('delay_cdf_load_%02d',k));
    savefig(f,[stem '.fig']);
    exportgraphics(f,[stem '.png'],'Resolution',200);
    exportgraphics(f,[stem '.pdf'],'ContentType','vector');
    close(f);
    fprintf('Validated and plotted load %.2f\n',loads(k));
end

R = cell2table(rows,'VariableNames',{'TotalLambda','Policy','AP','Runs', ...
    'CompletedWindowSamples','PooledP50','PooledP95','PooledP99', ...
    'MeanRunP95','MeanEndUnfinished'});
writetable(R,fullfile(outDir,'delay_cdf_summary.csv'));
fid = fopen(fullfile(outDir,'README.txt'),'w');
assert(fid >= 0);
fprintf(fid,'Source: %s\n',batchDir);
fprintf(fid,'Included completions: Twarmup <= completion time <= Tsim.\n');
fprintf(fid,'Packets arriving before warmup may be included if they complete in the window.\n');
fprintf(fid,'Unfinished packets are excluded from delay CDFs and reported separately.\n');
fprintf(fid,'Pooled quantiles weight packets equally; MeanRunP95 weights runs equally.\n');
fprintf(fid,'CDFs are descriptive; packet samples are not independent replications.\n');
fclose(fid);
disp(R(R.AP == 0,:));
fprintf('\nAll 180 runs validated against run_metrics.csv.\nSaved to:\n%s\n',outDir);

function q = local_quantile(x,p)
% Match the existing engine's linear interpolation exactly.
x = sort(x(:));
assert(~isempty(x));
pos = 1+(numel(x)-1)*p;
lo = floor(pos); hi = ceil(pos);
q = x(lo)+(pos-lo)*(x(hi)-x(lo));
end
