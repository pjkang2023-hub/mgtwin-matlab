%% How mgtwin.identify estimates a grid-forming converter's parameters
% A worked example. A "truth" plant stands in for the real converter: we
% simulate it, add measurement noise, and then identify its parameters from
% that noisy trace as if we had measured it - so we can see how close the
% estimate comes, and when the tool refuses to claim confidence.
%
% Run from the mgtwin-matlab folder:  run examples/identify_example.m

%% 1. The experiment: a load step on an islanded converter
% Load steps from 0.20 to 0.50 pu at t = 1 s; 8 s recorded at 2 ms
% (PMU-grade sampling).
[t, p] = mgtwin.loadStep(t_end=8, dt=0.002, t_step=1, p_before=0.20, p_after=0.50);

%% 2. The "real" converter (unknown to the identifier)
% 4 % P-f droop, 0.25 s power-measurement lag, 1.5 s virtual inertia.
RP_TRUE = 0.04;  TP_TRUE = 0.25;  H_TRUE = 1.5;
truth = mgtwin.simulateGfm(t, p, RP_TRUE, TP_TRUE, H_TRUE);   % columns [omega_pu, Pm_pu]

% What we "measure": frequency in pu, with 1 mHz-class noise.
rng(1);
y_meas = truth(:, 1) + 2e-5 * randn(size(t));

%% 3. The model we fit, and where the optimiser starts
% predict(theta) runs the same RMS model with candidate parameters and
% returns the frequency it would produce.
predict = @(th) column(mgtwin.simulateGfm(t, p, th.rp_pu, th.tp_sec, th.h_sec), 1);
theta0  = struct("rp_pu", 0.03, "tp_sec", 0.10, "h_sec", 1.0);        % a datasheet-ish guess
bounds  = struct("rp_pu", [0.005 0.2], "tp_sec", [0.01 2], "h_sec", [0.05 10]);

%% 4. Identify
% lsqnonlin minimises predict(theta) - y_meas; then the Jacobian gives the
% standard errors and the condition number, and the residuals are tested
% for whiteness before any confidence is claimed.
res = mgtwin.identify(predict, y_meas, theta0, bounds);
disp(res.render())
fprintf("\ntruth:     rp_pu=%.4g  tp_sec=%.4g  h_sec=%.4g\n", RP_TRUE, TP_TRUE, H_TRUE);

%% 5. The same identification with historian-rate data (1 s, 50 mHz steps)
% Same plant, same model - only the instrumentation differs. The tool now
% refuses: the experiment cannot separate the parameters.
k = 1:500:numel(t);                                       % every 1 s
y_slow = round(y_meas(k) * 50 / 0.05) * 0.05 / 50;        % 0.05 Hz quantisation at 50 Hz
predict_slow = @(th) pick(column(mgtwin.simulateGfm(t, p, th.rp_pu, th.tp_sec, th.h_sec), 1), k);
res_slow = mgtwin.identify(predict_slow, y_slow, theta0, bounds);
fprintf("\n--- historian-rate data ---\n"); disp(res_slow.render())

%% 6. The trap: a ramp limit the model does not contain
% The real converter limits its power ramp (0.15 pu/s); the model has no such
% term. The fit still converges and its intervals look tight - but the
% residuals are not white, and the verdict says so.
truth_rl = mgtwin.simulateGfm(t, p, RP_TRUE, TP_TRUE, H_TRUE, ramp_limit_pu_s=0.15);
y_rl = truth_rl(:, 1) + 2e-5 * randn(size(t));
res_rl = mgtwin.identify(predict, y_rl, theta0, bounds);
fprintf("\n--- truth with an unmodelled ramp limit ---\n"); disp(res_rl.render())

%% 7. Two step sizes: the consistency check
% A linear model must give the same parameters at every amplitude. Two steps
% (0.2 -> 0.5 and 0.2 -> 0.3 pu) with the correct model agree, and the
% parameters are pooled. The whiteness tests run at 1 % significance, so
% now and then a correct fit's noise looks structured and the tool refuses
% (with rng(1) carried on here, the second experiment's noise trips the
% Ljung-Box test at p = 0.006 though its estimates are right): it errs on
% the side of refusing, by design.
[t2, p2] = mgtwin.loadStep(t_end=8, dt=0.002, t_step=1, p_before=0.20, p_after=0.30);
truth2 = mgtwin.simulateGfm(t2, p2, RP_TRUE, TP_TRUE, H_TRUE);
rng(2);
y2 = truth2(:, 1) + 2e-5 * randn(size(t2));
predict2 = @(th) column(mgtwin.simulateGfm(t2, p2, th.rp_pu, th.tp_sec, th.h_sec), 1);
mres = mgtwin.identifyMulti({{predict, y_meas}, {predict2, y2}}, theta0, bounds);
fprintf("\n--- two step sizes ---\n"); disp(mres.render())

function c = column(m, j)
c = m(:, j);
end

function v = pick(v, k)
v = v(k);
end
