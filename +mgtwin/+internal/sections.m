function root = sections(site, isl, without, open_extra)
%SECTIONS Electrical sections of state ISL: union-find over its closed
%   switches (less the switch ids OPEN_EXTRA), branches and transformers
%   (less the transformer ids WITHOUT).
%
%   A switch open in the state (Site.openSwitchIds) severs every edge between
%   its two buses, as a breaker in series with whatever it switches does.
%   Returns ROOT, a (1,n) vector aligned with site.busIds(): two buses are in
%   one section exactly when their ROOT values are equal.
arguments
    site (1,1) mgtwin.Site
    isl (1,1) mgtwin.IslandConfig
    without (1,:) string = string.empty(1,0)
    open_extra (1,:) string = string.empty(1,0)
end
busIds = site.busIds();
n = numel(busIds);
idx = dictionary(busIds, 1:n);
opened = unique([site.openSwitchIds(isl), open_extra]);

openKeys = string.empty(1,0);
for k = 1:numel(site.switches)
    sw = site.switches(k);
    if ismember(sw.id, opened)
        openKeys(end+1) = pairKey(sw.from_bus, sw.to_bus); %#ok<AGROW>
    end
end

edges = zeros(0, 2);
keys = string.empty(0, 1);
for k = 1:numel(site.branches)
    br = site.branches(k);
    edges(end+1, :) = [idx(br.from_bus), idx(br.to_bus)]; %#ok<AGROW>
    keys(end+1, 1) = pairKey(br.from_bus, br.to_bus); %#ok<AGROW>
end
for k = 1:numel(site.transformers)
    tx = site.transformers(k);
    if ismember(tx.id, without), continue; end
    edges(end+1, :) = [idx(tx.hv_bus), idx(tx.lv_bus)]; %#ok<AGROW>
    keys(end+1, 1) = pairKey(tx.hv_bus, tx.lv_bus); %#ok<AGROW>
end
for k = 1:numel(site.switches)
    sw = site.switches(k);
    if ismember(sw.id, opened), continue; end
    edges(end+1, :) = [idx(sw.from_bus), idx(sw.to_bus)]; %#ok<AGROW>
    keys(end+1, 1) = pairKey(sw.from_bus, sw.to_bus); %#ok<AGROW>
end
edges = edges(~ismember(keys, openKeys), :);

parent = 1:n;
for e = 1:size(edges, 1)
    ra = findRoot(parent, edges(e, 1));
    rb = findRoot(parent, edges(e, 2));
    if ra ~= rb
        parent(ra) = rb;
    end
end
root = arrayfun(@(b) findRoot(parent, b), 1:n);
end

function r = findRoot(parent, x)
r = x;
while parent(r) ~= r
    r = parent(r);
end
end

function key = pairKey(a, b)
s = sort([string(a), string(b)]);
key = s(1) + "|" + s(2);
end
