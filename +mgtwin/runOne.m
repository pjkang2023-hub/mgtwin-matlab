function r = runOne(sc, seed, protocol)
%RUNONE Score one (scenario, seed) identification run.
%   r = mgtwin.runOne(sc, seed, "single")  -- one load step
%   r = mgtwin.runOne(sc, seed, "multi")   -- large + small step with the
%                                             amplitude-consistency gate
arguments
    sc (1,1) mgtwin.Scenario
    seed (1,1) double
    protocol (1,1) string = "single"
end
C = mgtwin.evalConstants();
truth = struct("rp_pu", sc.params.rp_pu, "tp_sec", sc.params.tp_sec);
theta0 = struct("rp_pu", 0.03, "tp_sec", 0.40);
bounds = struct("rp_pu", [0.005, 0.20], "tp_sec", [0.01, 2.0]);

if protocol == "single"
    e = mgtwin.evalExperiment(sc, seed, sc.step);
    res = mgtwin.identify(e{1}, e{2}, theta0, bounds);
    theta_named = res.thetaStruct();
    verdict = res.verdict;
else
    exps = {mgtwin.evalExperiment(sc, seed, sc.step), ...
            mgtwin.evalExperiment(sc, seed + 1000, C.SMALL_STEP)};
    mres = mgtwin.identifyMulti(exps, theta0, bounds);
    verdict = mres.verdict;
    if ~isempty(mres.theta_pooled)
        theta_named = struct();
        for k = 1:numel(mres.names)
            theta_named.(mres.names(k)) = mres.theta_pooled(k);
        end
    else
        % refused: score bias on the large-step fit (what a naive user
        % would have taken)
        theta_named = mres.results(1).thetaStruct();
    end
end
bias = struct();
for n = string(fieldnames(truth))'
    bias.(n) = (theta_named.(n) - truth.(n)) / truth.(n);
end
bad = max(abs(struct2array(bias))) >= C.BIAS_LIMIT;
refused = verdict.isRefusal();
if refused && bad
    cell = "true_refusal";
elseif refused
    cell = "over_refusal";
elseif bad
    cell = "false_confidence";
else
    cell = "true_confidence";
end
r = mgtwin.EvalRun(sc.name, sc.mismatch, seed, verdict, bias, cell);
end
