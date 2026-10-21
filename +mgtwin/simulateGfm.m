function out = simulateGfm(t, p_load, rp_pu, tp_sec, h_sec, opts)
%SIMULATEGFM RMS-timescale grid-forming converter feeding an islanded load.
%
%   out = mgtwin.simulateGfm(t, p_load, rp_pu, tp_sec, h_sec, ...
%                            p_ref=0, ramp_limit_pu_s=[], omega0=1)
%
%   Fixed-step RK4 over the supplied time vector. Fixed step, not adaptive,
%   on purpose: adaptive stepping hides marginal stability behind a shrinking
%   dt, so a model that is numerically fragile looks converged. If this
%   integrator goes unstable the model deserves to look unstable.
%
%   Convention (declared, checked, never inferred)
%     - omega in pu of nominal frequency; 1.0 = nominal.
%     - Pm is the measured converter output in pu on converter rating,
%       GENERATOR positive: a positive Pm means injection.
%     - rp_pu is the P-f droop: steady state omega = 1 - rp_pu * (Pm - p_ref).
%       So rp_pu = 0.05 means 5% droop, i.e. full output swings frequency by 5%.
%
%   State equations, d/dt [omega, Pm]:
%     2H * d(omega)/dt = (p_ref - Pm) - (omega - 1) / rp_pu
%     Tp * d(Pm)/dt    = p_e - Pm            [optionally rate-limited]
%
%   The omega equation has the droop term as a restoring feedback, so the
%   steady state is omega = 1 + rp_pu * (p_ref - Pm): output above reference
%   pulls frequency down. Sign errors here invert the whole response, which
%   is why the convention is written out rather than assumed.
%
%   `ramp_limit_pu_s` exists so that a TRUTH trajectory can be generated with
%   a structure the library form does not contain -- a real BESS ramp limit.
%   That is how model-form mismatch gets injected on purpose, rather than
%   being discovered in commissioning.
%
%   Returns an [numel(t) x 2] array with columns [omega_pu, p_m_pu].
arguments
    t (:,1) double
    p_load (:,1) double
    rp_pu (1,1) double
    tp_sec (1,1) double
    h_sec (1,1) double
    opts.p_ref (1,1) double = 0.0
    opts.ramp_limit_pu_s double = []
    opts.omega0 (1,1) double = 1.0
end
if numel(t) ~= numel(p_load)
    error("mgtwin:ValueError", "t and p_load must have the same shape");
end
if any(diff(t) <= 0)
    error("mgtwin:ValueError", "t must be strictly increasing");
end
p_ref = opts.p_ref;
hasRamp = ~isempty(opts.ramp_limit_pu_s);
if hasRamp, ramp = opts.ramp_limit_pu_s; else, ramp = Inf; end
inv2H = 1.0 / (2.0 * h_sec);
invRp = 1.0 / rp_pu;
invTp = 1.0 / tp_sec;

n = numel(t);
out = zeros(n, 2);
w = opts.omega0;
pm = p_load(1);
out(1, :) = [w, pm];

% RHS inlined (no function-call overhead in the hot loop):
%   dw  = ((p_ref - pm) - (w - 1) * invRp) * inv2H
%   dpm = clip((pe - pm) * invTp, -ramp, ramp)
for k = 1:n - 1
    dt = t(k + 1) - t(k);
    pe0 = p_load(k); pe1 = p_load(k + 1);
    pe_mid = 0.5 * (pe0 + pe1);   % zero-order hold, midpoint for half steps

    k1w = ((p_ref - pm) - (w - 1.0) * invRp) * inv2H;
    k1p = (pe0 - pm) * invTp;
    if hasRamp, k1p = min(max(k1p, -ramp), ramp); end

    w2 = w + 0.5 * dt * k1w; p2 = pm + 0.5 * dt * k1p;
    k2w = ((p_ref - p2) - (w2 - 1.0) * invRp) * inv2H;
    k2p = (pe_mid - p2) * invTp;
    if hasRamp, k2p = min(max(k2p, -ramp), ramp); end

    w3 = w + 0.5 * dt * k2w; p3 = pm + 0.5 * dt * k2p;
    k3w = ((p_ref - p3) - (w3 - 1.0) * invRp) * inv2H;
    k3p = (pe_mid - p3) * invTp;
    if hasRamp, k3p = min(max(k3p, -ramp), ramp); end

    w4 = w + dt * k3w; p4 = pm + dt * k3p;
    k4w = ((p_ref - p4) - (w4 - 1.0) * invRp) * inv2H;
    k4p = (pe1 - p4) * invTp;
    if hasRamp, k4p = min(max(k4p, -ramp), ramp); end

    w = w + (dt / 6.0) * (k1w + 2 * k2w + 2 * k3w + k4w);
    pm = pm + (dt / 6.0) * (k1p + 2 * k2p + 2 * k3p + k4p);
    out(k + 1, 1) = w;
    out(k + 1, 2) = pm;
end
end
