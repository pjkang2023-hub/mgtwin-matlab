function rep = gateProtection(site)
%GATEPROTECTION Gate 3: will the protection operate when islanded, in the
%   settings group each state runs?
%
%   Grid-connected, the utility contributes 5-10 pu of fault current and
%   overcurrent grading works. Islanded, the sources are current-limited
%   converters contributing perhaps 1.1-1.5 pu of their own rating. Relay
%   settings carried over from the grid-connected study may simply never
%   pick up. That is the finding that blocks energization, so it is FAIL,
%   not WARN.
%
%   Per islanded state, for the elements active in its settings group:
%     * a closed breaker whose relay has no element active in the group is
%       unprotected in that state: FAIL;
%     * every phase overcurrent element with a pickup (50, 51, 67) against
%       the available fault current, with the dependability margin - FAIL
%       short of it, unless unit elements active in the group cover the
%       breaker's circuit: the element is then its backup, and a backup
%       short of margin is a WARN (breaker failure, 50BF, is the backup
%       that does not rest on magnitude);
%     * converter-dominated states: the breakers whose primary protection
%       rests on magnitude alone (no 21 or 51V element, and no unit element
%       whose zones cover both sides of the breaker) are named in a WARN;
%     * a breaker fed from both sides with only non-directional overcurrent
%       sees the through-faults the far side can drive: phase, when that
%       side's fault contribution exceeds the margin times its rating (a
%       machine's, not a converter's 1.1-1.5 pu); earth, when each side has
%       an earthing source. WARN, it needs direction (67 / 67N) or unit
%       protection;
%     * phase elements whose pickup is not yet set are named, not screened
%       (WARN).
%   Earth-fault elements are not screened: their current is the
%   zero-sequence path's. Screening only - grading, settings and fault
%   levels are a protection study's (Electrisim), whose results the
%   envelope takes.
import mgtwin.Finding mgtwin.Severity
rep = mgtwin.GateReport();

% Dependability margin. A relay needs meaningfully more than pickup to
% operate in a useful time on an inverse curve, not merely to exceed it.
PROTECTION_MARGIN = mgtwin.gateProtectionConstants().PROTECTION_MARGIN;
% Above this converter share of fault current, overcurrent grading is
% regarded as structurally marginal regardless of the arithmetic.
CONVERTER_DOMINANCE = mgtwin.gateProtectionConstants().CONVERTER_DOMINANCE;
PHASE_OC = mgtwin.ProtectionFunction.PHASE_OC;
EARTH_OC = mgtwin.ProtectionFunction.EARTH_OC;
NOT_MAGNITUDE = mgtwin.ProtectionFunction.NOT_MAGNITUDE;
UNIT = mgtwin.ProtectionFunction.UNIT;
LEGACY = mgtwin.ProtectionFunction.LEGACY_ELEMENT;

if isempty(site.relays)
    rep.add(Finding("protection", Severity.WARN, ...
        "no relays declared; islanded protection cannot be screened", site.id));
    return;
end

busIds = site.busIds();
for k = 1:numel(site.islands)
    isl = site.islands(k);
    if isl.grid_connected
        continue;
    end

    conv_a = 0.0;
    mach_a = 0.0;
    for j = 1:numel(isl.energized_source_ids)
        src = site.source(isl.energized_source_ids(j));
        if isa(src, "mgtwin.Converter")
            conv_a = conv_a + src.faultContributionA(site.base);
        elseif isa(src, "mgtwin.SynchronousGen")
            mach_a = mach_a + src.faultContributionA(site.base);
        end
    end

    total_a = conv_a + mach_a;
    if total_a <= 0
        rep.add(Finding("protection", Severity.FAIL, ...
            "no energized sources declared for this island", isl.id));
        continue;
    end

    openSw = site.openSwitchIds(isl);
    inService = site.relays(~ismember(string({site.relays.switch_id}), openSw));
    group = isl.settings_group;

    % elements with a pickup to screen, in relay order
    ocRelay = mgtwin.OvercurrentRelay.empty(1,0);
    ocElem = mgtwin.ProtectionFunction.empty(1,0);
    unset = string.empty(1,0);
    for j = 1:numel(inService)
        r = inService(j);
        act = r.active(group);
        if isempty(act)
            rep.add(Finding("protection", Severity.FAIL, ...
                sprintf("no element of relay %s is active in settings group '%s': breaker %s is unprotected in this state", ...
                r.id, group, r.switch_id), isl.id + "/" + r.id, ...
                "Give the relay an element in this group, or run the state in a group it has."));
            continue;
        end
        for e = act
            if ismember(e.ansi, PHASE_OC) && ~isempty(e.pickup_a)
                ocRelay(end+1) = r; %#ok<AGROW>
                ocElem(end+1) = e; %#ok<AGROW>
            elseif ismember(e.ansi, PHASE_OC)
                unset(end+1) = r.id + " " + e.ansi; %#ok<AGROW>
            end
        end
    end
    if ~isempty(unset)
        msg = sprintf("%d phase overcurrent element(s) with no pickup set are not screened: ", numel(unset)) + ...
            strjoin(unset(1:min(8, end)), ", ");
        if numel(unset) > 8, msg = msg + sprintf(" and %d more", numel(unset) - 8); end
        rep.add(Finding("protection", Severity.WARN, msg, isl.id + "/unset", ...
            "Declare the settings once the setting study has them (pickup in primary amperes)."));
    end

    swIds = string({site.switches.id});
    % A unit element protects the breaker's circuit only if its zones take in
    % both sides of the breaker (a feeder's 87L, a bus section between two
    % 87B zones) - not a board's 87B on a breaker leaving it.
    unitCovers = @(r, act) unitZoneCovers(site.switches(swIds == r.switch_id), act, UNIT);

    for j = 1:numel(ocElem)
        r = ocRelay(j); e = ocElem(j);
        if e.notes == LEGACY
            scope = isl.id + "/" + r.id;
        else
            scope = isl.id + "/" + r.id + "/" + e.ansi;
        end
        ratio = total_a / e.pickup_a;
        act = r.active(group);
        if ratio < PROTECTION_MARGIN && unitCovers(r, act)
            ansis = string({act.ansi});
            units = unique(ansis(ismember(ansis, UNIT)));
            rep.add(Finding("protection", Severity.WARN, ...
                sprintf("backup %s at %s A has %.2fx pickup from the island's %s A, below the %gx margin; " + ...
                "%s covers the circuit and is its primary protection", e.ansi, ...
                mgtwin.internal.fmtThousands(e.pickup_a), ratio, mgtwin.internal.fmtThousands(total_a), ...
                PROTECTION_MARGIN, strjoin(units, "/")), scope, ...
                "Back the unit protection up with breaker failure (50BF) or a duplicated scheme; " + ...
                "a backup pickup cannot be lowered below the load it must carry."));
        elseif ratio < 1.0
            rep.add(Finding("protection", Severity.FAIL, ...
                sprintf("available islanded fault current %s A is below pickup %s A (ratio %.2f); this relay will never operate", ...
                mgtwin.internal.fmtThousands(total_a), mgtwin.internal.fmtThousands(e.pickup_a), ratio), scope, ...
                "Islanded settings group, voltage-restrained or voltage-controlled overcurrent, " + ...
                "differential, or communication-assisted scheme per IEEE 2030.12."));
        elseif ratio < PROTECTION_MARGIN
            rep.add(Finding("protection", Severity.FAIL, ...
                sprintf("fault current %s A gives only %.2fx pickup, below the %gx dependability margin; operating time will be very long", ...
                mgtwin.internal.fmtThousands(total_a), ratio, PROTECTION_MARGIN), scope, ...
                "Lower the islanded pickup or change scheme; do not rely on an inverse curve this close to pickup."));
        else
            rep.add(Finding("protection", Severity.PASS, ...
                sprintf("%.1fx pickup available when islanded", ratio), scope));
        end
    end

    protectedRelays = mgtwin.OvercurrentRelay.empty(1,0);
    for j = 1:numel(inService)
        if ~isempty(inService(j).active(group)), protectedRelays(end+1) = inService(j); end %#ok<AGROW>
    end
    magnitudeOnly = string.empty(1,0);
    for j = 1:numel(protectedRelays)
        act = protectedRelays(j).active(group);
        if ~unitCovers(protectedRelays(j), act) && ...
                ~any(ismember(string({act.ansi}), setdiff(NOT_MAGNITUDE, UNIT, "stable")))
            magnitudeOnly(end+1) = protectedRelays(j).id; %#ok<AGROW>
        end
    end
    share = conv_a / total_a;
    if share >= CONVERTER_DOMINANCE && (~isempty(magnitudeOnly) || isempty(protectedRelays))
        msg = sprintf("%.0f%% of islanded fault current comes from current-limited converters; " + ...
            "magnitude-based grading is structurally marginal here even where the arithmetic passes", 100 * share);
        if ~isempty(magnitudeOnly)
            msg = msg + " - primary protection rests on magnitude at " + strjoin(magnitudeOnly(1:min(8, end)), ", ");
            if numel(magnitudeOnly) > 8
                msg = msg + sprintf(" and %d more", numel(magnitudeOnly) - 8);
            end
        end
        rep.add(Finding("protection", Severity.WARN, msg, isl.id, ...
            "Treat overcurrent as backup only; primary protection should not depend on fault-current magnitude (87L/87B, or 51V)."));
    elseif share >= CONVERTER_DOMINANCE
        rep.add(Finding("protection", Severity.PASS, ...
            sprintf("%.0f%% converter fault current, and every breaker in service has protection " + ...
            "that does not rest on magnitude alone", 100 * share), isl.id));
    end

    % Breakers fed from both sides: non-directional overcurrent sees a
    % through-fault the far side can drive. Phase: the far side's fault
    % contribution above PROTECTION_MARGIN x its rated current (a synchronous
    % machine's 1/x''; a converter's 1.1-1.5 pu is not - a pickup above its
    % load with margin does not see it). Earth: an earthing source on each
    % side at the breaker's voltage. Unless a 67 / 67N or a unit element
    % covering the breaker's circuit is there.
    srcs = arrayfun(@(sid) {site.source(sid)}, isl.energized_source_ids);
    busKv = [site.buses.v_nom_kv];
    earths = string.empty(1,0);
    for g = site.grounding(:)'
        if g.kind ~= mgtwin.GroundingKind.UNGROUNDED && g.available_when_islanded
            earths(end+1) = g.bus; %#ok<AGROW>
        end
    end
    for tx = site.transformers(:)'
        if tx.providesZeroSequencePathTo("hv"), earths(end+1) = tx.hv_bus; end %#ok<AGROW>
        if tx.providesZeroSequencePathTo("lv"), earths(end+1) = tx.lv_bus; end %#ok<AGROW>
    end
    iRated = @(mva) mva * 1e6 / (sqrt(3) * site.base.v_base_kv * 1e3);
    lowRatio = string.empty(1,0);
    for j = 1:numel(protectedRelays)
        r = protectedRelays(j);
        act = r.active(group);
        unit = unitCovers(r, act);
        ansis = string({act.ansi});
        dirs = arrayfun(@(e) e.isDirectional(), act);
        blind = string.empty(1,0);
        kinds = {"phase", PHASE_OC; "earth", EARTH_OC};
        for q = 1:2
            inK = ismember(ansis, kinds{q, 2});
            if ~unit && any(inK & ~dirs) && ~any(inK & dirs)
                blind(end+1) = kinds{q, 1}; %#ok<AGROW>
            end
        end
        if isempty(blind)
            continue;
        end
        sw = site.switches(swIds == r.switch_id);
        if sw.from_bus == sw.to_bus
            continue;
        end
        cut = mgtwin.internal.sections(site, isl, string.empty(1,0), sw.id);
        rootOf = @(b) cut(busIds == b);
        ends = [rootOf(sw.from_bus), rootOf(sw.to_bus)];
        if ends(1) == ends(2)
            continue;
        end
        seen = string.empty(1,0);
        seenKinds = string.empty(1,0);
        if ismember("phase", blind)
            ratios = zeros(1, 2);
            for q = 1:2
                fault = 0; mva = 0;
                for m = 1:numel(srcs)
                    x = srcs{m};
                    if rootOf(x.bus) == ends(q)
                        fault = fault + x.faultContributionA(site.base);
                        mva = mva + x.s_rated_mva;
                    end
                end
                if mva > 0, ratios(q) = fault / iRated(mva); end
            end
            if min(ratios) > 0 && max(ratios) > PROTECTION_MARGIN
                seen(end+1) = sprintf("phase (the far side gives %.1fx its rated current)", max(ratios)); %#ok<AGROW>
                seenKinds(end+1) = "phase"; %#ok<AGROW>
            elseif min(ratios) > 0
                lowRatio(end+1) = r.switch_id; %#ok<AGROW>
            end
        end
        if ismember("earth", blind)
            kv0 = busKv(busIds == sw.from_bus);
            atKv = earths(arrayfun(@(b) any(busIds == b) && abs(busKv(busIds == b) - kv0) < 1e-6, earths));
            eachSide = true;
            for q = 1:2
                eachSide = eachSide && any(arrayfun(@(b) rootOf(b) == ends(q), atKv));
            end
            if eachSide
                seen(end+1) = "earth (an earthing source on each side)"; %#ok<AGROW>
                seenKinds(end+1) = "earth"; %#ok<AGROW>
            end
        end
        if ~isempty(seen)
            codes = replace(replace(seenKinds, "phase", "67"), "earth", "67N");
            rep.add(Finding("protection", Severity.WARN, ...
                sprintf("breaker %s is fed from both sides; relay %s's non-directional overcurrent " + ...
                "sees through-faults: %s", r.switch_id, r.id, strjoin(seen, "; ")), ...
                isl.id + "/" + r.id, ...
                "Add a directional element (" + strjoin(codes, " / ") + ") or unit protection (87L) on this breaker."));
        end
    end
    if ~isempty(lowRatio)
        msg = sprintf("%d breaker(s) fed from both sides by converters only, whose fault current is within " + ...
            "%gx their rating: a phase pickup above load with margin does not see the through-fault (", ...
            numel(lowRatio), PROTECTION_MARGIN) + strjoin(lowRatio(1:min(6, end)), ", ");
        if numel(lowRatio) > 6, msg = msg + " ..."; end
        rep.add(Finding("protection", Severity.PASS, msg + ")", isl.id + "/through-faults"));
    end
end
end


function tf = unitZoneCovers(sw, act, UNIT)
%UNITZONECOVERS The union of the unit elements' zones takes in both ends of SW.
zone = string.empty(1,0);
for e = act
    if ismember(e.ansi, UNIT), zone = [zone, reshape(e.zone_buses, 1, [])]; end %#ok<AGROW>
end
tf = all(ismember([sw.from_bus, sw.to_bus], zone));
end
