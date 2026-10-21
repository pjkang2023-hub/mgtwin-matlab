function exp = evalExperiment(sc, seed, step)
%EVALEXPERIMENT Build one {predict, y} experiment for scenario SC at STEP.
%   The predictor is the LIBRARY form (simulateGfm) with h_sec fixed at the
%   truth value; only rp_pu and tp_sec are estimated.
sc2 = sc;
sc2.step = step;
[t, p, idx, y] = mgtwin.makeMeasurement(sc2, seed);
p0 = step(1);
h_sec = sc.params.h_sec;
predict = @(theta) predictGfm(t, p, theta, h_sec, p0, idx);
exp = {predict, y};
end

function yhat = predictGfm(t, p, theta, h_sec, p0, idx)
out = mgtwin.simulateGfm(t, p, theta.rp_pu, theta.tp_sec, h_sec, p_ref=p0);
yhat = out(idx, 1);
end
