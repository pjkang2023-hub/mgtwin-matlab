function rep = gateEnergisation(site)
%GATEENERGISATION Can the grid-forming sources of a section absorb the
%   magnetising inrush of the transformers switched in together?
%
%   Converter-formed islands have no stiff source: the inrush of a
%   transformer is served by the current-limited PCS (and any machine) in the
%   section, less the current already carrying the section's load. A step
%   whose summed peak inrush exceeds that headroom drives the forming units
%   into current limit, collapses section voltage and risks a cascade trip of
%   grid-following units. The multiple inrush_pu is ASSUMED unless
%   inrush_identified is set; the verdict says so. Static check only:
%   remanence, point-on-wave and sympathetic inrush need an EMT study, which
%   this gate names when it warns.
%
%   A step whose transformer no energised source reaches FAILs as such ("the
%   step energises nothing"), so a state that forgets to close a normally
%   open leg is caught rather than passed.
import mgtwin.Finding mgtwin.Severity
rep = mgtwin.GateReport();
busIds = site.busIds();
idx = dictionary(busIds, 1:numel(busIds));
txIds = string({site.transformers.id});
toA = 1e6 / (sqrt(3) * site.base.v_base_kv * 1e3);

for k = 1:numel(site.islands)
    isl = site.islands(k);
    if isempty(isl.energise_transformer_ids)
        continue;
    end
    root = mgtwin.internal.sections(site, isl, isl.energise_transformer_ids);
    energized = isl.energized_source_ids;
    txs = site.transformers(arrayfun(@(t) find(txIds == t, 1), ...
        isl.energise_transformer_ids(ismember(isl.energise_transformer_ids, txIds))));
    txRoot = arrayfun(@(tx) root(idx(tx.hv_bus)), txs);
    for r = reshape(unique(txRoot, "stable"), 1, [])
        buses = busIds(root == r);
        step = txs(txRoot == r);
        names = strjoin(string({step.id}), ", ");
        label = sprintf("%s/energise(%s)", isl.id, mgtwin.internal.zoneName(site, buses));
        if ~anySourceIn(site, energized, buses)
            rep.add(Finding("energisation", Severity.FAIL, ...
                sprintf("%s: no energised source reaches the HV side in this state - " + ...
                "the step energises nothing", names), label, ...
                "Close the switch that connects it (a normally open leg goes in the state's " + ...
                "closed_switches), or correct the state's open switches."));
            continue;
        end
        gfmMva = 0; gflMva = 0; machMva = 0;
        for j = 1:numel(site.converters)
            c = site.converters(j);
            if ~ismember(c.id, energized) || ~ismember(c.bus, buses), continue; end
            if c.control == mgtwin.ConverterControl.GFL
                gflMva = gflMva + c.s_rated_mva;
            else
                gfmMva = gfmMva + c.s_rated_mva * c.params.i_limit_transient_pu;
            end
        end
        for j = 1:numel(site.machines)
            m = site.machines(j);
            if ismember(m.id, energized) && ismember(m.bus, buses)
                machMva = machMva + m.s_rated_mva / max(m.xd_subtransient_pu, 0.05);
            end
        end
        loadMva = 0;
        [pState, qState] = site.stateLoads(isl);
        for j = 1:numel(site.loads)
            if ismember(site.loads(j).bus, buses)
                loadMva = loadMva + hypot(pState(j), qState(j));
            end
        end
        % the forming units already carry whatever the grid-following fleet
        % does not; only the remainder of their current limit is available
        % for inrush
        deficitMva = max(loadMva - gflMva, 0);
        headPk = max(gfmMva + machMva - deficitMva, 0) * toA * sqrt(2);
        inrushPk = sum([step.inrush_pu] .* [step.s_rated_mva]) * toA;
        assumed = any(~[step.inrush_identified]);
        if assumed, prov = "ASSUMED inrush multiple"; else, prov = "IDENTIFIED inrush"; end
        if headPk > 0, ratio = inrushPk / headPk; else, ratio = Inf; end
        if isinf(ratio), ratioS = "inf"; else, ratioS = sprintf("%.2f", ratio); end
        msg = sprintf("%d transformer(s) [%s] switched together: summed peak inrush " + ...
            "%.0f A pk against forming headroom %.0f A pk (ratio %s; %s)", ...
            numel(step), names, inrushPk, headPk, ratioS, prov);
        if ratio > 1.0
            rep.add(Finding("energisation", Severity.FAIL, msg, label, ...
                "Sequence the closings (one transformer per step), use point-on-wave " + ...
                "closing with remanence tracking, pre-magnetise from the LV side, or add " + ...
                "forming capacity. Confirm with an EMT study."));
        elseif ratio > 0.8 || assumed
            rep.add(Finding("energisation", Severity.WARN, msg, label, ...
                "Within headroom on the assumed multiple; identify the inrush multiple " + ...
                "and check remanence / point-on-wave in an EMT study."));
        else
            rep.add(Finding("energisation", Severity.PASS, msg, label));
        end
    end
end
end

function tf = anySourceIn(site, energized, buses)
tf = false;
for j = 1:numel(site.machines)
    if ismember(site.machines(j).id, energized) && ismember(site.machines(j).bus, buses)
        tf = true; return;
    end
end
for j = 1:numel(site.converters)
    if ismember(site.converters(j).id, energized) && ismember(site.converters(j).bus, buses)
        tf = true; return;
    end
end
end
