function q = my_quantile(x, p)
% MY_QUANTILE  Linear-interpolation quantile, no toolbox required.
% p in [0,1]. Matches MATLAB prctile 'linear' convention.

if isempty(x)
    q = NaN;
    return;
end

x = sort(x(:));
n = numel(x);
if n == 1
    q = x;
    return;
end

pos = 1 + (n - 1) * p;
lo = floor(pos);
hi = ceil(pos);

if lo == hi
    q = x(lo);
else
    q = x(lo) + (pos - lo) * (x(hi) - x(lo));
end
end