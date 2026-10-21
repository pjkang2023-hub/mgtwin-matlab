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
%       the available fault current, with the dependability margin;
%     * converter-dominated states: the breakers whose primary protection
%       rests on magnitude alone (no 87, 21 or 51V element) are named in a
%       WARN;
%     * a breaker that fault current reaches from both sides (energised
%       sources on each) with only non-directional overcurrent sees
%       through-faults: WARN, it needs direction (67) or unit protection.
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
            end
        end
    end

    for j = 1:numel(ocElem)
        r = ocRelay(j); e = ocElem(j);
        if e.notes == LEGACY
            scope = isl.id + "/" + r.id;
        else
            scope = isl.id + "/" + r.id + "/" + e.ansi;
        end
        ratio = total_a / e.pickup_a;
        if ratio < 1.0
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
        if ~any(ismember(string({act.ansi}), NOT_MAGNITUDE))
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

    % Breakers fed from both sides: non-directional overcurrent sees through-faults.
    srcIds = [string({site.machines.id}), string({site.converters.id})];
    srcBus = [string({site.machines.bus}), string({site.converters.bus})];
    energized = isl.energized_source_ids;
    for j = 1:numel(protectedRelays)
        r = protectedRelays(j);
        act = r.active(group);
        ansis = string({act.ansi});
        if any(arrayfun(@(e) e.isDirectional(), act)) || ~any(ismember(ansis, [PHASE_OC, EARTH_OC]))
            continue;
        end
        sw = site.switches(string({site.switches.id}) == r.switch_id);
        if sw.from_bus == sw.to_bus
            continue;
        end
        cut = mgtwin.internal.sections(site, isl, string.empty(1,0), sw.id);
        rootOf = @(b) cut(busIds == b);
        ends = [rootOf(sw.from_bus), rootOf(sw.to_bus)];
        if ends(1) == ends(2)
            continue;
        end
        fed = false(1, 2);
        for s_ = energized
            m = find(srcIds == s_, 1);
            if isempty(m), continue; end
            fed = fed | (rootOf(srcBus(m)) == ends);
        end
        if all(fed)
            rep.add(Finding("protection", Severity.WARN, ...
                sprintf("fault current reaches breaker %s from both sides (energised sources on each); " + ...
                "relay %s's non-directional overcurrent sees through-faults", r.switch_id, r.id), ...
                isl.id + "/" + r.id, ...
                "Add a directional element (67 / 67N) or unit protection (87L) on this breaker."));
        end
    end
end
end
