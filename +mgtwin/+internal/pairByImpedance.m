function [paired, mismatch] = pairByImpedance(branches, kv_of, insts, s_base_mva)
%PAIRBYIMPEDANCE Pair the .m's transformer branches with the .mdl's physical
%   instances: within each voltage class, the one-to-one assignment that
%   minimises the summed |log(x_branch / x_instance)|, both on the system
%   base (an instance's from its own Z% and X/R). Ties - identical branches,
%   identical units - go in order: earlier branch, earlier instance.
%
%   paired:   dictionary branch id -> {MdlTransformer}
%   mismatch: dictionary branch id -> relative mismatch, for pairs > 5 % apart
paired = dictionary(string.empty, cell.empty);
mismatch = dictionary(string.empty, double.empty);
xSys = @(t) t.z_pct / 100 * t.xr / sqrt(1 + t.xr^2) * s_base_mva / (t.kva / 1e3);
classKey = @(hv, lv) sprintf("%g/%g", hv, lv);

instKeys = arrayfun(@(t) classKey(t.vp_v / 1e3, t.vs_v / 1e3), insts);
rowKeys = strings(0, 1); rowIdx = [];
for k = 1:numel(branches)
    br = branches(k);
    if ~startsWith(br.id, "TX_"), continue; end
    kf = kv_of(double(extractAfter(br.from_bus, 1)));
    kt = kv_of(double(extractAfter(br.to_bus, 1)));
    rowKeys(end+1, 1) = classKey(max(kf, kt), min(kf, kt)); %#ok<AGROW>
    rowIdx(end+1, 1) = k; %#ok<AGROW>
end
for key = unique(rowKeys, "stable")'
    brs = branches(rowIdx(rowKeys == key));
    pool = insts(instKeys == key);
    if isempty(pool), continue; end
    cost = zeros(numel(brs), numel(pool));
    for r = 1:numel(brs)
        for c = 1:numel(pool)
            cost(r, c) = abs(log(brs(r).x_pu / xSys(pool(c))));
        end
    end
    % every branch must be paired when the class has enough instances
    pairs = sortrows(matchpairs(cost - min(cost(:)) + 1, 1e6), 1);
    % Ties (identical branches, identical units) go in order - earlier branch,
    % earlier instance: swap any two pairs out of order when the swap leaves
    % the total cost unchanged.
    swapped = true;
    while swapped
        swapped = false;
        for a = 1:size(pairs, 1)
            for b = a+1:size(pairs, 1)
                ra = pairs(a, 1); ca = pairs(a, 2); rb = pairs(b, 1); cb = pairs(b, 2);
                if ca > cb && abs(cost(ra, cb) + cost(rb, ca) - cost(ra, ca) - cost(rb, cb)) < 1e-12
                    pairs(a, 2) = cb; pairs(b, 2) = ca; swapped = true;
                end
            end
        end
    end
    for p = 1:size(pairs, 1)
        br = brs(pairs(p, 1)); t = pool(pairs(p, 2));
        paired{br.id} = t;
        m = abs(br.x_pu / xSys(t) - 1);
        if m > 0.05, mismatch(br.id) = round(m, 4); end
    end
end
end
