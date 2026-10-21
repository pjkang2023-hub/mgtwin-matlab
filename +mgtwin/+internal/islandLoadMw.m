function p_mw = islandLoadMw(site, isl)
%ISLANDLOADMW Load served in this island. Approximation, documented: buses
%   reachable from the energized sources with the island's switches open --
%   reuses the electrical-island component from the grounding machinery.
zones = mgtwin.internal.zeroSequenceZones(site, isl);
buses = string.empty(1,0);
for k = 1:numel(zones)
    buses = [buses, zones{k}]; %#ok<AGROW>
end
p_mw = 0.0;
for k = 1:numel(site.loads)
    if ismember(site.loads(k).bus, buses)
        p_mw = p_mw + site.loads(k).p_mw;
    end
end
end
