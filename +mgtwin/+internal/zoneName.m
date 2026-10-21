function s = zoneName(site, buses)
%ZONENAME Short label for a set of buses: their voltages, and the bus ids
%   when there are three or fewer, else the count.
kvs = [];
for k = 1:numel(site.buses)
    if ismember(site.buses(k).id, buses)
        kvs(end+1) = site.buses(k).v_nom_kv; %#ok<AGROW>
    end
end
kvs = unique(kvs);
kv_s = strjoin(arrayfun(@(k) sprintf("%gkV", k), kvs), "/");
if numel(buses) <= 3
    s = kv_s + ":" + strjoin(sort(buses), ",");
else
    s = sprintf("%s:%d buses", kv_s, numel(buses));
end
end
