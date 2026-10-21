function omega = simulatePlant(t, p_load, pp)
%SIMULATEPLANT Truth plant for identification evals: RK4, fixed step;
%   returns omega_pu(t) as a column vector.
%
%   Kept separate from simulateGfm on purpose: that is the clean library
%   form the identifier fits; this is the adversary. The two must never
%   share an RHS, or the eval tests the copy machine.
%
%   State: [omega_pu, p_m, (p_m2 if extra_lag)]. Same droop convention as
%   simulateGfm; the mechanisms wrap it.
arguments
    t (:,1) double
    p_load (:,1) double
    pp (1,1) mgtwin.PlantParams
end
hasLag = ~isempty(pp.extra_lag_sec);
hasRamp = ~isempty(pp.ramp_limit_pu_s);
hasDb = ~isempty(pp.deadband_hz);
hasClamp = ~isempty(pp.p_max_pu);
hasKnee = ~isempty(pp.knee);
if hasLag, n_state = 3; else, n_state = 2; end
state = zeros(n_state, 1);
state(1) = 1.0;
state(2) = p_load(1);
if hasLag, state(3) = p_load(1); end

n = numel(t);
omega = zeros(n, 1);
omega(1) = state(1);
for k = 1:n - 1
    dt = t(k + 1) - t(k);
    pe0 = p_load(k); pe1 = p_load(k + 1);
    pem = 0.5 * (pe0 + pe1);
    k1 = rhs(state, pe0);
    k2 = rhs(state + 0.5 * dt * k1, pem);
    k3 = rhs(state + 0.5 * dt * k2, pem);
    k4 = rhs(state + dt * k3, pe1);
    state = state + (dt / 6.0) * (k1 + 2 * k2 + 2 * k3 + k4);
    omega(k + 1) = state(1);
end

    function out = rhs(s, p_e)
        w = s(1); p_m = s(2);
        if hasLag, p_for_swing = s(3); else, p_for_swing = p_m; end

        % droop / governor term with optional deadband and knee
        d_omega_pu = w - 1.0;
        d_f_hz = d_omega_pu * pp.f_nom;
        rp = pp.rp_pu;
        gov_err = d_omega_pu;
        if hasDb
            if abs(d_f_hz) <= pp.deadband_hz
                gov_err = 0.0;
            else
                gov_err = (d_f_hz - sign(d_f_hz) * pp.deadband_hz) / pp.f_nom;
            end
        end
        if hasKnee
            if abs(d_f_hz) > pp.knee(1)
                rp = pp.knee(2);
            end
        end

        d_omega = ((pp.p_ref - p_for_swing) - gov_err / rp) / (2.0 * pp.h_sec);

        d_pm = (p_e - p_m) / pp.tp_sec;
        if hasRamp
            d_pm = min(max(d_pm, -pp.ramp_limit_pu_s), pp.ramp_limit_pu_s);
        end
        if hasClamp && p_m >= pp.p_max_pu && d_pm > 0
            d_pm = 0.0;
        end

        if hasLag
            out = [d_omega; d_pm; (p_m - s(3)) / pp.extra_lag_sec];
        else
            out = [d_omega; d_pm];
        end
    end
end
