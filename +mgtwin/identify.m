function res = identify(predict, y_meas, theta0, bounds)
%IDENTIFY Least-squares identification plus an identifiability and validity report.
%
%   res = mgtwin.identify(predict, y_meas, theta0, bounds)
%
%   predict : function handle, predict(theta) -> column vector the size of
%             y_meas, where theta is a struct keyed by parameter name.
%   y_meas  : measured response (vector).
%   theta0  : struct of initial guesses, e.g. struct("rp_pu", 0.03, "tp_sec", 0.4).
%   bounds  : struct of [lo hi] per parameter.
%
%   The point of this function is not the optimiser. Any optimiser will
%   return a number. The point is that the report refuses to claim
%   confidence it has not earned:
%     - Fisher-information intervals are only valid if the model form is
%       correct. Under model-form mismatch they are optimistically biased,
%       often badly, while looking perfectly tight.
%     - So residual whiteness is tested first, and a failure DOWNGRADES the
%       verdict regardless of how small the standard errors are.
%
%   Requires Optimization Toolbox (lsqnonlin, trust-region-reflective --
%   the same algorithm family as scipy's least_squares(method="trf")).
C = mgtwin.identifyConstants();

names = string(fieldnames(theta0))';
p = numel(names);
x0 = zeros(1, p); lo = zeros(1, p); hi = zeros(1, p);
for k = 1:p
    x0(k) = theta0.(names(k));
    b = bounds.(names(k));
    lo(k) = b(1); hi(k) = b(2);
end
y = double(y_meas(:));

    function th = toStruct(x)
        th = struct();
        for j = 1:p
            th.(names(j)) = x(j);
        end
    end

resid_fn = @(x) reshape(predict(toStruct(x)), [], 1) - y;

opts = optimoptions("lsqnonlin", ...
    "Algorithm", "trust-region-reflective", ...
    "Display", "off", ...
    "FunctionTolerance", 1e-10, ...
    "StepTolerance", 1e-10, ...
    "OptimalityTolerance", 1e-10, ...
    "MaxFunctionEvaluations", 5000, ...
    "MaxIterations", 500, ...
    "TypicalX", x0);
[theta, ~, resid, ~, ~, ~, jac] = lsqnonlin(resid_fn, x0, lo, hi, opts);
theta = theta(:)';
resid = resid(:);
jac = full(jac);
n = numel(resid);

dof = max(n - p, 1);
sigma2 = (resid' * resid) / dof;
sigma_hat = sqrt(sigma2);
rmse = sqrt(mean(resid .^ 2));

% Scale to relative sensitivities so the condition number is dimensionless
% and does not merely reflect the units of the parameters.
scale = abs(theta);
scale(scale == 0) = 1.0;
jac_scaled = jac .* scale;

% Fisher information and covariance.
fim = (jac' * jac) / sigma2;
notes = string.empty(1,0);
if rcond(fim) < eps
    std_err = inf(1, p);
    notes(end+1) = "Fisher information matrix is singular; no finite intervals exist";
else
    cov = inv(fim);
    std_err = sqrt(max(diag(cov), 0))';
end

rel_se = inf(1, p);
nz = abs(theta) > 0;
rel_se(nz) = std_err(nz) ./ abs(theta(nz));

% Condition number and the least-determined parameter combination.
svals = svd(jac_scaled);
if svals(end) > 0
    cond_number = svals(1) / svals(end);
else
    cond_number = Inf;
end
[~, ~, V] = svd(jac_scaled, "econ");
weak_vec = V(:, end)';
weak_direction = struct();
for k = 1:p
    weak_direction.(names(k)) = weak_vec(k);
end

whiteness = mgtwin.assessWhiteness(resid, p);

% -- verdict -------------------------------------------------------------
% Order matters. Model-form mismatch is checked first and dominates, because
% under mismatch the intervals are not merely wrong but confidently wrong,
% and a tight interval is then actively misleading.
if ~whiteness.white
    verdict = mgtwin.Verdict.STRUCTURAL_MISMATCH;
    notes(end+1) = "Residuals are structured, so the model form does not match the data. " + ...
        "The Fisher intervals above assume a correct model form and are therefore " + ...
        "optimistically biased -- do not report them as confidence.";
    notes(end+1) = "Estimates are biased by the missing structure. Add the missing mechanism " + ...
        "(limiter, extra lag, nonlinearity) or restrict the fit to the region where the " + ...
        "library form holds.";
elseif cond_number > C.COND_LIMIT || ~all(isfinite(rel_se))
    verdict = mgtwin.Verdict.NOT_IDENTIFIABLE;
    [~, imax] = max(abs(weak_vec));
    notes(end+1) = sprintf("This experiment does not separate the parameters: the direction " + ...
        "shown above is nearly flat, dominated by '%s'. Either fix a parameter from " + ...
        "datasheet, or change the stimulus (faster step, multi-sine, or a second operating point).", ...
        names(imax));
elseif any(rel_se > C.REL_SE_LIMIT)
    verdict = mgtwin.Verdict.WEAKLY_IDENTIFIED;
    weak = names(rel_se > C.REL_SE_LIMIT);
    notes(end+1) = sprintf("Marginal: %s exceed %.0f%% relative standard error. " + ...
        "Usable for trend, not for a protection setting.", strjoin(weak, ", "), 100 * C.REL_SE_LIMIT);
else
    verdict = mgtwin.Verdict.IDENTIFIED;
end

res = mgtwin.IdentificationResult();
res.names = names;
res.theta = theta;
res.std_err = std_err;
res.rel_se = rel_se;
res.cond_number = cond_number;
res.weak_direction = weak_direction;
res.sigma_hat = sigma_hat;
res.rmse = rmse;
res.whiteness = whiteness;
res.verdict = verdict;
res.notes = notes;
end
