function [t, p, idx, y] = makeMeasurement(sc, seed, opts)
%MAKEMEASUREMENT Simulate the truth plant and sample it PMU-style.
%   [t, p, idx, y] = mgtwin.makeMeasurement(sc, seed, dt_sim=0.002, t_end=8, dt_meas=0.02, sigma=2e-4)
%   Noise is drawn from MATLAB's default generator seeded with SEED (the
%   Python original uses numpy's default_rng; the streams differ, the
%   statistics do not).
arguments
    sc (1,1) mgtwin.Scenario
    seed (1,1) double
    opts.dt_sim (1,1) double = 0.002
    opts.t_end (1,1) double = 8.0
    opts.dt_meas (1,1) double = 0.02
    opts.sigma (1,1) double = 2.0e-4
end
t = (0:opts.dt_sim:opts.t_end + 0.5 * opts.dt_sim)';
t = t(t <= opts.t_end + 0.25 * opts.dt_sim);
p0 = sc.step(1); p1 = sc.step(2);
p = p1 * ones(size(t));
p(t < 1.0) = p0;
pp = sc.params;
pp.p_ref = p0;
omega = mgtwin.simulatePlant(t, p, pp);
idx = (1:round(opts.dt_meas / opts.dt_sim):numel(t))';
rs = RandStream("mt19937ar", "Seed", seed);
noise = opts.sigma;
if sc.name == "nominal_high_noise", noise = 5.0 * noise; end
y = omega(idx) + noise * randn(rs, numel(idx), 1);
if ~isempty(sc.quantize_pu)
    y = round(y / sc.quantize_pu) * sc.quantize_pu;
end
end
