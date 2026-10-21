function w = assessWhiteness(resid, n_params, alpha)
%ASSESSWHITENESS Residual whiteness: Ljung-Box portmanteau plus a
%   Wald-Wolfowitz runs test on residual signs. Both must pass.
%
%   Fisher-information confidence intervals are only valid if the model form
%   is correct. Under model-form mismatch they are optimistically biased,
%   often badly, while looking perfectly tight -- so whiteness is tested
%   FIRST and a failure downgrades the verdict regardless of interval width.
arguments
    resid (:,1) double
    n_params (1,1) double
    alpha (1,1) double = mgtwin.identifyConstants().WHITENESS_ALPHA
end
n = numel(resid);
lags = min(20, max(5, floor(n / 20)));
[q, p_lb] = ljungBox(resid, lags, n_params);
r = resid - mean(resid);
lag1 = (r(1:end-1)' * r(2:end)) / (r' * r);
[z, p_runs] = runsTest(resid);
white = (p_lb > alpha) && (p_runs > alpha);
w = mgtwin.WhitenessResult(q, p_lb, lag1, z, p_runs, white);
end

function [q, p] = ljungBox(resid, lags, n_params)
% Q = n(n+2) * sum_{k=1..h} rho_k^2 / (n - k),  Q ~ chi2(h - n_params)
n = numel(resid);
r = resid - mean(resid);
denom = r' * r;
q = 0.0;
for k = 1:lags
    rho = (r(1:end-k)' * r(k+1:end)) / denom;
    q = q + rho * rho / (n - k);
end
q = q * n * (n + 2);
dof = max(lags - n_params, 1);
p = gammainc(q / 2, dof / 2, "upper");   % chi-square survival function
end

function [z, p] = runsTest(resid)
% Structured residuals produce far fewer sign changes than white noise, so a
% large negative z is direct evidence of an unmodelled deterministic trend.
signs = sign(resid - median(resid));
signs = signs(signs ~= 0);
n = numel(signs);
n_pos = sum(signs > 0);
n_neg = n - n_pos;
if n_pos == 0 || n_neg == 0
    z = -Inf; p = 0.0;
    return;
end
runs = 1 + sum(signs(2:end) ~= signs(1:end-1));
mu = 2.0 * n_pos * n_neg / n + 1.0;
v = (2.0 * n_pos * n_neg * (2.0 * n_pos * n_neg - n)) / (n * n * (n - 1.0));
if v <= 0
    z = 0.0; p = 1.0;
    return;
end
z = (runs - mu) / sqrt(v);
p = erfc(abs(z) / sqrt(2));   % two-sided normal tail
end
