function rep = gateUnits(site)
%GATEUNITS Gate 1: order-of-magnitude screening on declared quantities, plus
%   per-unit base consistency across branches.
%
%   Catches the two commonest classes: an impedance entered in ohms into a pu
%   field, and a branch whose pu impedance refers to a base nobody rebased
%   from.
import mgtwin.Finding mgtwin.Severity
rep = mgtwin.GateReport();

pairs = {"s_base_mva", site.base.s_base_mva; "v_base_kv", site.base.v_base_kv};
for k = 1:size(pairs, 1)
    msg = mgtwin.checkPlausible(pairs{k, 1}, pairs{k, 2});
    if strlength(msg) > 0
        rep.add(Finding("units", Severity.FAIL, msg, site.id));
    end
end

for k = 1:numel(site.branches)
    br = site.branches(k);
    msg = mgtwin.checkPlausible("z_pu", br.x_pu);
    if strlength(msg) > 0
        rep.add(Finding("units", Severity.FAIL, "branch reactance: " + msg, br.id, ...
            "Confirm whether the value was entered in ohms rather than pu."));
    end
    if br.r_pu > 0
        xr = br.x_pu / br.r_pu;
        msg = mgtwin.checkPlausible("x_over_r", xr);
        if strlength(msg) > 0
            rep.add(Finding("units", Severity.WARN, ...
                sprintf("X/R = %.2f is unusual for this voltage class", xr), br.id, ...
                "Check for a transposed R and X."));
        end
    end
    % Per-unit base consistency: a branch declaring a base other than the
    % site base must be rebased before it is used.
    if abs(br.s_base_mva - site.base.s_base_mva) > 1e-9 || abs(br.v_base_kv - site.base.v_base_kv) > 1e-9
        rep.add(Finding("units", Severity.WARN, ...
            sprintf("pu impedance refers to %g MVA / %g kV, not the site base (%g MVA / %g kV)", ...
            br.s_base_mva, br.v_base_kv, site.base.s_base_mva, site.base.v_base_kv), br.id, ...
            "Rebase with Base.rebaseImpedance before assembling the network."));
    end
end

for k = 1:numel(site.converters)
    c = site.converters(k);
    p = c.params;
    checks = {"droop_pu", p.p_f_droop_pu; "h_sec", p.h_sec; "tp_sec", p.tp_sec; "i_limit_pu", p.i_limit_transient_pu};
    for j = 1:size(checks, 1)
        val = checks{j, 2};
        if isempty(val), continue; end
        msg = mgtwin.checkPlausible(checks{j, 1}, val);
        if strlength(msg) > 0
            rep.add(Finding("units", Severity.FAIL, msg, c.id));
        end
    end
end

% Transformer reactance: on its own rating a power transformer's is some
% 4-15 %. A value far outside that was entered on another base - the site's,
% typically - and scales every fault level and voltage drop through it.
off = mgtwin.Transformer.empty(0,1);
for k = 1:numel(site.transformers)
    if strlength(mgtwin.checkPlausible("tx_x_pu", site.transformers(k).x_pu)) > 0
        off(end+1, 1) = site.transformers(k); %#ok<AGROW>
    end
end
if ~isempty(off)
    band = mgtwin.plausibleRanges().tx_x_pu;
    listed = arrayfun(@(tx) sprintf("%s %g", tx.id, tx.x_pu), off(1:min(8, end)));
    more = "";
    if numel(off) > 8, more = sprintf(" and %d more", numel(off) - 8); end
    rep.add(Finding("units", Severity.FAIL, ...
        sprintf("%d transformer reactance(s) outside [%g, %g] pu on their own rating: ", ...
        numel(off), band(1), band(2)) + strjoin(listed, ", ") + more, site.id, ...
        "Transformer.x_pu is on the transformer's own rating; rebase a system-base value " + ...
        "(x_own = x_sys * s_rated / s_base)."));
end

% Transformer ratio vs declared bus voltages.
busKv = dictionary(string.empty, double.empty);
for k = 1:numel(site.buses)
    busKv(site.buses(k).id) = site.buses(k).v_nom_kv;
end
for k = 1:numel(site.transformers)
    tx = site.transformers(k);
    sides = {"hv", tx.hv_kv, tx.hv_bus; "lv", tx.lv_kv, tx.lv_bus};
    for j = 1:2
        side = sides{j, 1}; kv = sides{j, 2}; bus = sides{j, 3};
        if ~isKey(busKv, bus), continue; end
        nom = busKv(bus);
        if abs(kv - nom) / nom > 0.10
            rep.add(Finding("units", Severity.FAIL, ...
                sprintf("%s winding rated %g kV but bus '%s' is nominally %g kV", side, kv, bus, nom), ...
                tx.id, "A mismatched ratio silently scales every downstream current."));
        end
    end
end

if isempty(rep.findings)
    rep.add(Finding("units", Severity.PASS, "declared quantities are dimensionally plausible"));
end
end
