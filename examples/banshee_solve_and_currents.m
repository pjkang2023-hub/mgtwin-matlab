function [results, cands] = banshee_solve_and_currents(case_path)
%BANSHEE_SOLVE_AND_CURRENTS Solve a Banshee MATPOWER case with MATPOWER's
%   runpf and return branch-end currents in amperes.
%
%   cands is a struct array with fields name ("f-t:from" / "f-t:to"),
%   i_a (amperes) and feeder (1..3). MATPOWER solves the released case
%   natively -- loads (Pd/Qd), bus shunts (Gs/Bs) and impedance branches in
%   pu on the system base with the ratio absorbed by the bus voltage bases,
%   exactly what the pandapower rebuild in the Python original reproduced.
mpc = mgtwin.loadMatpowerCase(case_path);
mpopt = mpoption("verbose", 0, "out.all", 0, "pf.tol", 1e-8, "pf.nr.max_it", 60);
results = runpf(mpc, mpopt);
if ~results.success
    error("mgtwin:ConvergenceError", "MATPOWER power flow did not converge for %s", case_path);
end
kv_of = dictionary(results.bus(:, 1), results.bus(:, 10));
vm_of = dictionary(results.bus(:, 1), results.bus(:, 8));
cands = struct("name", {}, "i_a", {}, "feeder", {});
for k = 1:size(results.branch, 1)
    f = results.branch(k, 1); t = results.branch(k, 2);
    % |I| = |S| / (sqrt(3) * |V|) at each end, S in MVA (PF/QF, PT/QT), V in kV
    s_from = hypot(results.branch(k, 14), results.branch(k, 15));
    s_to = hypot(results.branch(k, 16), results.branch(k, 17));
    i_from = s_from * 1e6 / (sqrt(3) * vm_of(f) * kv_of(f) * 1e3);
    i_to = s_to * 1e6 / (sqrt(3) * vm_of(t) * kv_of(t) * 1e3);
    nm = sprintf("%d-%d", f, t);
    cands(end+1) = struct("name", nm + ":from", "i_a", i_from, "feeder", feederOfEnd(f, t)); %#ok<AGROW>
    cands(end+1) = struct("name", nm + ":to", "i_a", i_to, "feeder", feederOfEnd(f, t)); %#ok<AGROW>
end
end

function fdr = feederOfBus(b)
if b >= 200, fdr = 3; elseif b >= 20, fdr = 2; else, fdr = 1; end
end

function fdr = feederOfEnd(f, t)
if f == 1
    fdr = feederOfBus(t);
elseif t == 1
    fdr = feederOfBus(f);
else
    fdr = feederOfBus(f);
end
end
