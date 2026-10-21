function ok = ieee4_rung2()
%IEEE4_RUNG2 Eval rung 2: verify the unbalanced solver against the IEEE
%   4-node test feeder.
%
%   The 4-node feeder exists for exactly one purpose: verifying transformer
%   connection models in unbalanced power flow. Two connections are
%   exercised here, chosen for what the microgrid work needs:
%     * grounded-wye / grounded-wye -- the zero-sequence-continuous case
%     * delta / grounded-wye        -- Banshee's connection, zero-seq blocking
%
%   Published references are the IEEE test feeder solutions (unbalanced
%   load, step-down); magnitudes are published rounded to 1 V and angles to
%   0.1 deg, which sets the achievable agreement floor.
%
%   Feeder: 12.47 kV infinite bus -- 2000 ft line -- 6 MVA 12.47/4.16 kV
%   transformer (R=1%, X=6%) -- 2500 ft line -- unbalanced wye load
%   (A: 1275 kW @ 0.85, B: 1800 kW @ 0.90, C: 2375 kW @ 0.95, lagging).
addpath(fullfile(fileparts(mfilename("fullpath")), ".."));
RULE = string(repmat('=', 1, 78));
D = ieee4_data();

disp(RULE);
disp("RUNG 2  Unbalanced solver vs the IEEE 4-node test feeder");
disp(RULE);
fprintf("Published magnitudes are rounded to 1 V and angles to 0.1 deg, so\nagreement within %.0f V / %g deg is the achievable floor.\n", D.TOL_V, D.TOL_DEG);

conns = ["GrY-GrY", "D-GrY"];
results = false(1, 2);
for k = 1:2
    results(k) = checkCase(conns(k), D);
end

fprintf("\n%s\n", RULE);
ok = all(results);
for k = 1:2
    if results(k), s = "PASS"; else, s = "FAIL"; end
    fprintf("  %-10s %s\n", conns(k), s);
end
if ok
    fprintf("\nWhat this buys: the transformer connection algebra (including the\n" + ...
        "30-degree delta/grounded-wye shift and its zero-sequence blocking)\n" + ...
        "is now verified against the case the IEEE built for that purpose --\n" + ...
        "so when the same matrices quantify SLG overvoltages on Banshee's\n" + ...
        "islands, the machinery has a pedigree rather than a promise.\n");
else
    fprintf("\nDo not build on this until the deviations are explained.\n");
end
end

function ok = checkCase(connection, D)
feeder = ieee4_build(connection);
[v_nodes, i_load] = feeder.solve();
got = struct("v3", mgtwin.polar(v_nodes{3}), "v4", mgtwin.polar(v_nodes{4}));
ref = D.REFS.(matlab.lang.makeValidName(connection));

fprintf("\n%s  (transformer low-side and load-node LN voltages)\n", connection);
fprintf("  %-5s%-4s%16s%18s%8s%8s\n", "node", "ph", "published", "computed", "d|V|", "d_ang");
ok = true;
ph = 'abc';
for node = ["v3", "v4"]
    for p = 1:3
        mr = ref.(node)(p, 1); ar = ref.(node)(p, 2);
        mc = got.(node)(p, 1); ac = got.(node)(p, 2);
        dm = mc - mr; da = ac - ar;
        flag = "";
        if abs(dm) > D.TOL_V || abs(da) > D.TOL_DEG
            ok = false; flag = "  <-- OUT OF TOLERANCE";
        end
        fprintf("  %-5s%-4s%9.0f /_%6.1f%11.1f /_%6.2f%8.2f%8.3f%s\n", node, ph(p), mr, ar, mc, ac, dm, da, flag);
    end
end
pl = mgtwin.polar(i_load);
parts = strings(1, 3);
for p = 1:3, parts(p) = sprintf("%.1f A /_%.1f", pl(p, 1), pl(p, 2)); end
fprintf("  load currents: %s\n", strjoin(parts, "  "));
end
