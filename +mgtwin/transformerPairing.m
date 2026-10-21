function T = transformerPairing(case_path, mdl_path)
%TRANSFORMERPAIRING For review: each transformer branch of the Banshee .m,
%   the .mdl instance paired with it by impedance, and the mismatch.
%
%   T = mgtwin.transformerPairing(case_path, mdl_path) returns a table with
%   variables branch, instance, kva, mismatch. On case v5 all but three
%   branches match an instance exactly; three match none and take their
%   class's remaining unit: the two 13.8/0.48 kV branches of x 0.2977
%   (TX_30_40 a 2500 kVA, 32 % apart; TX_80_110 the 5000 kVA, 51 %) and the
%   4.16/0.48 kV TX_50_60 (x 0.752, the 1500 kVA's, against the remaining
%   1000 kVA, 33 %). The .m and the .mdl disagree there; the rating is the .mdl's.
arguments
    case_path (1,1) string
    mdl_path (1,1) string
end
site = mgtwin.composeBanshee(case_path);   % branches only; no .mdl
mpc = mgtwin.loadMatpowerCase(case_path);
kv_of = dictionary(mpc.bus(:, 1), mpc.bus(:, 10));
insts = mgtwin.extractMdlTransformers(mdl_path);
insts = insts(~arrayfun(@(t) t.isHilArtifact(), insts));
[paired, mismatch] = mgtwin.internal.pairByImpedance(site.branches, kv_of, insts, mpc.baseMVA);
ids = keys(paired);
branch = ids; instance = strings(numel(ids), 1); kva = zeros(numel(ids), 1); mm = zeros(numel(ids), 1);
for k = 1:numel(ids)
    t = paired{ids(k)};
    instance(k) = t.name; kva(k) = t.kva;
    if isKey(mismatch, ids(k)), mm(k) = mismatch(ids(k)); end
end
T = table(branch, instance, kva, mm, VariableNames=["branch", "instance", "kva", "mismatch"]);
end
