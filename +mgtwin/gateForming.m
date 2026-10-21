function rep = gateForming(site)
%GATEFORMING Every electrically connected section of every islanded
%   configuration must contain at least one grid-forming source (synchronous
%   machine, or a converter not in grid-following control).
%
%   A section of grid-following converters alone has no voltage/frequency
%   reference and collapses the moment it is sectionalised -- the gate a
%   topology study needs when the plant has few grid-forming units
%   (CAMPAIGN-003: 4 GFM among 22).
import mgtwin.Finding mgtwin.Severity
rep = mgtwin.GateReport();

gfmIds = string({site.machines.id});
srcIds = gfmIds;
srcBus = string({site.machines.bus});
for k = 1:numel(site.converters)
    c = site.converters(k);
    srcIds(end+1) = c.id; %#ok<AGROW>
    srcBus(end+1) = c.bus; %#ok<AGROW>
    if c.control ~= mgtwin.ConverterControl.GFL
        gfmIds(end+1) = c.id; %#ok<AGROW>
    end
end
busIds = site.busIds();
idx = dictionary(busIds, 1:numel(busIds));

for k = 1:numel(site.islands)
    isl = site.islands(k);
    if isl.grid_connected || isempty(isl.energized_source_ids)
        continue;
    end
    root = mgtwin.internal.sections(site, isl);
    energized = unique(isl.energized_source_ids, "stable");
    srcRoot = arrayfun(@(sid) root(idx(srcBus(srcIds == sid))), energized);
    for r = reshape(unique(srcRoot, "stable"), 1, [])
        here = energized(srcRoot == r);
        gfm = sort(here(ismember(here, gfmIds)));
        nGfl = sum(~ismember(here, gfmIds));
        buses = busIds(root == r);
        label = sprintf("%s/section(%s)", isl.id, mgtwin.internal.zoneName(site, buses));
        [pState, ~] = site.stateLoads(isl);
        mw = sum(pState(ismember(string({site.loads.bus}), buses)));
        if ~isempty(gfm)
            rep.add(Finding("forming", Severity.PASS, ...
                sprintf("%d grid-forming source(s) %s for %d grid-following, %.1f MW load", ...
                numel(gfm), pyList(gfm), nGfl, mw), label));
        else
            rep.add(Finding("forming", Severity.FAIL, ...
                sprintf("no grid-forming source in this section (%d grid-following " + ...
                "sources, %.1f MW load): no voltage/frequency reference -- the section " + ...
                "collapses when sectionalised", nGfl, mw), label, ...
                "Keep the section coupled to one containing a grid-forming unit, add a " + ...
                "grid-forming source to it, or make its sectionalising breaker a " + ...
                "sources-off interlock."));
        end
    end
end
end

function s = pyList(ids)
%PYLIST Render ids as the Python report does: ['A', 'B'].
s = "[" + strjoin("'" + ids + "'", ", ") + "]";
end
