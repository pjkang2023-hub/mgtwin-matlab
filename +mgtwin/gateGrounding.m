function rep = gateGrounding(site)
%GATEGROUNDING Gate 2: grounding continuity across island transitions.
%
%   Every zero-sequence ZONE of every island that carries sources or load
%   must retain a zero-sequence source. Zones, not islands: delta windings
%   partition a network into independent zero-sequence regions, so an island
%   can be perfectly grounded at 480 V while its 13.8 kV level floats -- and
%   a site-level check would miss exactly that.
%
%   Requires topology. If neither grounding sources nor transformers are
%   declared, the site cannot be assessed and the gate FAILS on absence.
import mgtwin.Finding mgtwin.Severity
rep = mgtwin.GateReport();

if isempty(site.grounding) && isempty(site.transformers)
    rep.add(Finding("grounding", Severity.FAIL, ...
        "no grounding sources and no transformer winding data declared; " + ...
        "zero-sequence behaviour cannot be assessed", site.id, ...
        "Grounding is not optional metadata. Declare winding configurations and zero-sequence sources."));
    return;
end

for k = 1:numel(site.islands)
    isl = site.islands(k);
    if ~isl.grid_connected && isempty(isl.energized_source_ids)
        rep.add(Finding("grounding", Severity.WARN, ...
            "island declares no energized sources; nothing to assess " + ...
            "(if this island can really form, its sources are missing from the declaration)", isl.id));
        continue;
    end
    [zones, info] = mgtwin.internal.zeroSequenceZones(site, isl);
    for i = 1:numel(zones)
        meta = info(i);
        label = sprintf("%s/zone(%s)", isl.id, mgtwin.internal.zoneName(site, zones{i}));
        if ~isempty(meta.grounded_by)
            kinds = strjoin(sort(meta.kinds), ", ");
            rep.add(Finding("grounding", Severity.PASS, ...
                sprintf("zero-sequence source present (%s)", kinds), label));
            if isequal(unique(meta.kinds), "high_resistance_grounded")
                rep.add(Finding("grounding", Severity.WARN, ...
                    "only high-resistance grounding in this zone; " + ...
                    "ground-fault current may be below relay sensitivity", label));
            end
        elseif ~isempty(meta.declared_it)
            ids = strjoin(sort(meta.declared_it), ", ");
            rep.add(Finding("grounding", Severity.WARN, ...
                sprintf("ungrounded by DECLARED design (IT system: %s); first ", ids) + ...
                "earth fault produces no current and 1.73 pu on healthy " + ...
                "phases -- acceptable only with a ground detector (IMD or " + ...
                "59N), line-to-line insulation/arrester ratings, and a " + ...
                "first-fault operating rule", label, ...
                "Confirm the detector and the first-fault rule are in the " + ...
                "grounding design; otherwise ground the zone."));
        else
            if isl.grid_connected, sev = Severity.WARN; else, sev = Severity.FAIL; end
            rep.add(Finding("grounding", sev, ...
                "no zero-sequence source in this zone; SLG faults will drive unfaulted " + ...
                "phases toward ~1.73 pu and neutral-current ground-fault detection will not operate", ...
                label, ...
                "Add a grounding transformer in this zone, ground a machine neutral, or use a " + ...
                "grounded-wye winding on the in-zone side of a transformer."));
        end
    end
end

% Structural note: delta-delta passes zero sequence nowhere.
for k = 1:numel(site.transformers)
    tx = site.transformers(k);
    if tx.hv_config == mgtwin.WindingConfig.DELTA && tx.lv_config == mgtwin.WindingConfig.DELTA
        rep.add(Finding("grounding", Severity.WARN, ...
            "delta-delta transformer blocks zero sequence in both directions; " + ...
            "grounding must be established independently on each side", tx.id));
    end
end
end
