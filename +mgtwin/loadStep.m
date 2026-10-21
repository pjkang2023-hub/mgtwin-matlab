function [t, p] = loadStep(opts)
%LOADSTEP Standard load-step stimulus. Returns column vectors (t, p_load).
%   [t, p] = mgtwin.loadStep(t_end=8, dt=0.002, t_step=1, p_before=0.2, p_after=0.5)
arguments
    opts.t_end (1,1) double = 8.0
    opts.dt (1,1) double = 0.002
    opts.t_step (1,1) double = 1.0
    opts.p_before (1,1) double = 0.20
    opts.p_after (1,1) double = 0.50
end
t = (0:opts.dt:opts.t_end + 0.5 * opts.dt)';
t = t(t <= opts.t_end + 0.25 * opts.dt);
p = opts.p_after * ones(size(t));
p(t < opts.t_step) = opts.p_before;
end
