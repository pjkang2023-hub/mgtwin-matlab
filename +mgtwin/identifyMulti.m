function mres = identifyMulti(experiments, theta0, bounds)
%IDENTIFYMULTI Identification across multiple experiments at DIFFERENT
%   operating points (e.g. two step amplitudes), with a consistency gate.
%
%   mres = mgtwin.identifyMulti(experiments, theta0, bounds)
%
%   experiments : cell array of {predict_fn, y_meas} pairs; each predict_fn
%                 maps a theta struct to a prediction the shape of its y_meas.
%
%   Rationale: single-experiment residual whiteness is blind to amplitude-
%   dependent nonlinearities (deadband, saturation, piecewise droop) because
%   on one trajectory they masquerade as a parameter shift with near-white
%   residuals -- rung 4 measured a 33% false-confidence rate for exactly
%   that class. A linear model form, if correct, must return the SAME
%   parameters at every amplitude; disagreement beyond the combined
%   uncertainty is structural evidence no single experiment can supply.
%
%   Verdict logic, strictest first:
%     * any single experiment STRUCTURAL_MISMATCH / NOT_IDENTIFIABLE
%       -> that verdict propagates;
%     * parameters inconsistent across experiments -> STRUCTURAL_MISMATCH
%       ("operating-point-dependent parameters");
%     * any WEAKLY_IDENTIFIED -> WEAKLY_IDENTIFIED;
%     * else IDENTIFIED, with an inverse-variance pooled estimate.
C = mgtwin.identifyConstants();
names = string(fieldnames(theta0))';
nExp = numel(experiments);
results = mgtwin.IdentificationResult.empty(1,0);
for k = 1:nExp
    e = experiments{k};
    results(k) = mgtwin.identify(e{1}, e{2}, theta0, bounds);
end

mres = mgtwin.MultiIdentificationResult();
mres.results = results;
mres.names = names;
notes = string.empty(1,0);

verdicts = [results.verdict];
for bad = [mgtwin.Verdict.STRUCTURAL_MISMATCH, mgtwin.Verdict.NOT_IDENTIFIABLE]
    which = find(verdicts == bad);
    if ~isempty(which)
        notes(end+1) = sprintf("experiment(s) [%s] returned %s; see their notes", ...
            strjoin(string(which), ", "), bad.Value); %#ok<AGROW>
        mres.verdict = bad;
        mres.notes = notes;
        return;
    end
end

% Consistency across experiments.
theta = vertcat(results.theta);     % (n_exp, n_par)
se = vertcat(results.std_err);
spread_rel = struct();
inconsistent = string.empty(1,0);
for j = 1:numel(names)
    vals = theta(:, j);
    lo = min(vals); hi = max(vals);
    mid = 0.5 * (lo + hi);
    if mid ~= 0
        rel = (hi - lo) / abs(mid);
    else
        rel = Inf;
    end
    spread_rel.(names(j)) = rel;
    tol = max(C.CONSISTENCY_K * sqrt(sum(se(:, j) .^ 2)), C.CONSISTENCY_REL_FLOOR * abs(mid));
    if (hi - lo) > tol
        inconsistent(end+1) = names(j); %#ok<AGROW>
    end
end
mres.spread_rel = spread_rel;

if ~isempty(inconsistent)
    notes(end+1) = sprintf("parameters [%s] differ across operating points beyond the combined " + ...
        "uncertainty: the plant is nonlinear in a way the model form does not contain " + ...
        "(deadband, limiter, or piecewise characteristic). Each single-experiment fit looked " + ...
        "clean -- this is precisely the mismatch class residual whiteness cannot see, and why " + ...
        "the multi-amplitude protocol exists.", strjoin(inconsistent, ", "));
    mres.verdict = mgtwin.Verdict.STRUCTURAL_MISMATCH;
    mres.notes = notes;
    return;
end

% Pool (inverse-variance).
w = 1.0 ./ max(se, 1e-12) .^ 2;
mres.theta_pooled = sum(w .* theta, 1) ./ sum(w, 1);

if any(verdicts == mgtwin.Verdict.WEAKLY_IDENTIFIED)
    mres.verdict = mgtwin.Verdict.WEAKLY_IDENTIFIED;
    notes(end+1) = "at least one experiment only weakly identified";
else
    mres.verdict = mgtwin.Verdict.IDENTIFIED;
end
mres.notes = notes;
end
