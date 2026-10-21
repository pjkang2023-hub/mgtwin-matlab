function rep = gateLoading(site)
%GATELOADING Can the sources a state energises carry the load it leaves connected?
%
%   The other gates check that a section has a voltage reference, a
%   zero-sequence path and room for its inrush - not that its sources can
%   carry its load. A black-start state that leaves the halls' feeders closed
%   on a 3 MVA genset passes all of them. Per energised section of each
%   islanded state: FAIL when the load's apparent power exceeds the rating of
%   every source energised in it, storage included; WARN when it exceeds the
%   sustained sources' (machines and converters without storage) - the
%   section then runs on its batteries; and FAIL for a transformer feeding a
%   side with no source of its own whose load exceeds its rating. Ratings,
%   not a load flow: losses, voltage and temperature derating are not
%   counted, so a PASS is necessary, not sufficient.
import mgtwin.Finding mgtwin.Severity
rep = mgtwin.GateReport();
busIds = site.busIds();
idx = dictionary(busIds, 1:numel(busIds));

% Sources: machines, then converters (as Python's srcs mapping).
srcIds = string.empty(1,0); srcBus = string.empty(1,0);
srcMva = []; srcStorage = logical.empty(1,0);
for k = 1:numel(site.machines)
    m = site.machines(k);
    srcIds(end+1) = m.id; srcBus(end+1) = m.bus; %#ok<AGROW>
    srcMva(end+1) = m.s_rated_mva; srcStorage(end+1) = false; %#ok<AGROW>
end
for k = 1:numel(site.converters)
    c = site.converters(k);
    srcIds(end+1) = c.id; srcBus(end+1) = c.bus; %#ok<AGROW>
    srcMva(end+1) = c.s_rated_mva; srcStorage(end+1) = ~isempty(c.energy_mwh); %#ok<AGROW>
end
loadBus = string({site.loads.bus});
loadP = []; loadQ = [];   % the state's loads, set per island below
    function s = sLoad(mask)
        % apparent power of the state's loads on the buses in MASK
        on = ismember(loadBus, busIds(mask));
        s = hypot(sum(loadP(on)), sum(loadQ(on)));
    end

for k = 1:numel(site.islands)
    isl = site.islands(k);
    if isl.grid_connected || isempty(isl.energized_source_ids)
        continue;
    end
    [loadP, loadQ] = site.stateLoads(isl);
    root = mgtwin.internal.sections(site, isl);
    en = find(ismember(srcIds, isl.energized_source_ids));
    % keep the state's order of its sources
    [~, ord] = sort(arrayfun(@(j) find(isl.energized_source_ids == srcIds(j), 1), en));
    en = en(ord);
    enRoot = arrayfun(@(j) root(idx(srcBus(j))), en);
    for r = reshape(unique(enRoot, "stable"), 1, [])
        inSec = root == r;
        here = en(enRoot == r);
        total = sum(srcMva(here));
        sustained = sum(srcMva(here(~srcStorage(here))));
        load = sLoad(inSec);
        label = sprintf("%s/loading(%s)", isl.id, mgtwin.internal.zoneName(site, busIds(inSec)));
        if load > total * 1.0 + 1e-9
            rep.add(Finding("loading", Severity.FAIL, ...
                sprintf("the section's load %.2f MVA exceeds the rating of every source energised in it, " + ...
                "%.2f MVA (%d source(s)): it cannot be carried", load, total, numel(here)), label, ...
                "Open the feeders of the loads the state does not intend to carry (as a black-start " + ...
                "step should), or energise more sources."));
        elseif load > sustained + 1e-9 && total > sustained
            rep.add(Finding("loading", Severity.WARN, ...
                sprintf("the section's load %.2f MVA exceeds its sustained sources' %.2f MVA: " + ...
                "it runs on storage (%.2f MVA of it)", load, sustained, total - sustained), label, ...
                "Check the storage's energy against how long the state lasts."));
        else
            rep.add(Finding("loading", Severity.PASS, ...
                sprintf("load %.2f MVA within %.2f MVA sustained, %.2f MVA in all", load, sustained, total), label));
        end
        % Transformers carrying load with no source behind them.
        hereBus = idx(srcBus(here));
        for t = 1:numel(site.transformers)
            tx = site.transformers(t);
            if ~inSec(idx(tx.hv_bus)), continue; end
            cut = mgtwin.internal.sections(site, isl, tx.id);
            for endBus = [tx.hv_bus, tx.lv_bus]
                side = cut == cut(idx(endBus));
                if isequal(side, inSec) || any(side(hereBus)), continue; end
                behind = sLoad(side);
                if behind > tx.s_rated_mva * 1.0 + 1e-9
                    rep.add(Finding("loading", Severity.FAIL, ...
                        sprintf("%s (%g MVA) feeds %.2f MVA of load on a side with " + ...
                        "no source of its own (%.0f %%)", tx.id, tx.s_rated_mva, behind, ...
                        100 * behind / tx.s_rated_mva), isl.id + "/" + tx.id, ...
                        "Size the transformer (or its bank) for the load it feeds - for dual-corded " + ...
                        "loads, the whole load when the other cord is lost."));
                end
            end
        end
    end
end
end
