function rep = gateProtection(site)
%GATEPROTECTION Gate 3: will overcurrent protection operate when islanded?
%
%   Grid-connected, the utility contributes 5-10 pu of fault current and
%   overcurrent grading works. Islanded, the sources are current-limited
%   converters contributing perhaps 1.1-1.5 pu of their own rating. Relay
%   settings carried over from the grid-connected study may simply never
%   pick up. This is the finding that blocks energization, so it is FAIL,
%   not WARN.
import mgtwin.Finding mgtwin.Severity
rep = mgtwin.GateReport();

% Dependability margin. A relay needs meaningfully more than pickup to
% operate in a useful time on an inverse curve, not merely to exceed it.
PROTECTION_MARGIN = mgtwin.gateProtectionConstants().PROTECTION_MARGIN;
% Above this converter share of fault current, overcurrent grading is
% regarded as structurally marginal regardless of the arithmetic.
CONVERTER_DOMINANCE = mgtwin.gateProtectionConstants().CONVERTER_DOMINANCE;

if isempty(site.relays)
    rep.add(Finding("protection", Severity.WARN, ...
        "no relays declared; islanded protection cannot be screened", site.id));
    return;
end

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
    for j = 1:numel(site.relays)
        r = site.relays(j);
        if ismember(r.switch_id, openSw)
            continue;  % relay out of service with its open switch
        end
        ratio = total_a / r.pickup_a;
        scope = isl.id + "/" + r.id;
        if ratio < 1.0
            rep.add(Finding("protection", Severity.FAIL, ...
                sprintf("available islanded fault current %s A is below pickup %s A (ratio %.2f); this relay will never operate", ...
                mgtwin.internal.fmtThousands(total_a), mgtwin.internal.fmtThousands(r.pickup_a), ratio), scope, ...
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

    share = conv_a / total_a;
    if share >= CONVERTER_DOMINANCE
        rep.add(Finding("protection", Severity.WARN, ...
            sprintf("%.0f%% of islanded fault current comes from current-limited converters; " + ...
            "magnitude-based grading is structurally marginal here even where the arithmetic passes", 100 * share), ...
            isl.id, ...
            "Treat overcurrent as backup only; primary protection should not depend on fault-current magnitude."));
    end
end
end
