function ok = is_independent_set(APs, adjMatrix)
% IS_INDEPENDENT_SET  True if no two APs in APs share a conflict edge.

ok = true;
for i = 1:numel(APs)
    for j = i+1:numel(APs)
        if adjMatrix(APs(i), APs(j)) ~= 0
            ok = false;
            return;
        end
    end
end
end