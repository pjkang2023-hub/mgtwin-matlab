function demo()
%DEMO End-to-end demonstration.
%
%   Part 1  A composed site containing two defects that survive human
%           review: the grounding reference sits outside the microgrid, and
%           relay pickup was carried over from the grid-connected study.
%           Both are caught structurally.
%   Part 2  The same site remediated.
%   Part 3  Identification against known truth, four cases:
%             A  well-posed
%             B  three parameters incl. virtual inertia (trade-off named)
%             C  historian-grade data: NOT_IDENTIFIABLE
%             D  model-form mismatch, where tight intervals would be a lie
%   Part 4  The test suite carried as versioned data.
%
%   Part 3D is the case that matters. Everything else is bookkeeping.
addpath(fullfile(fileparts(mfilename("fullpath")), ".."));
RULE = string(repmat('=', 1, 78));

disp(RULE);
disp("PART 1  Composed site, as an engineer would first hand it over");
disp(RULE);
site = build_demo_site(false);
rep = mgtwin.runAllGates(site);
disp(rep.render());
fprintf("\ngate result: %s\n", blockedOrPassed(rep));

fprintf("\n%s\n", RULE);
disp("PART 2  Same site after remediation");
disp(RULE);
fixed_site = build_demo_site(true);
rep2 = mgtwin.runAllGates(fixed_site);
disp(rep2.render());
fprintf("\ngate result: %s\n", blockedOrPassed(rep2));
fprintf("\nThe converter-dominance warning survives remediation, correctly: the\n" + ...
    "arithmetic passes but magnitude-based grading is still the wrong scheme.\n");

fprintf("\n%s\n", RULE);
disp("PART 3  Identification against known truth");
disp(RULE);
ident = runIdentification();

fprintf("\n%s\n", RULE);
disp("PART 4  Test suite carried as versioned data, not code");
disp(RULE);
suite = mgtwin.loadSuite("ieee2030_8_2018");
fprintf("edition %s: %d cases, %d of which cannot be answered at RMS timescale\n", ...
    suite.edition, numel(suite.cases), numel(suite.emtCases()));
for k = 1:numel(suite.cases)
    c = suite.cases(k);
    if c.requires_emt, emt = " [EMT]"; else, emt = ""; end
    fprintf("  %-10s %-22s%s\n", c.id, c.core_function.Value, emt);
end
unset = 0;
for k = 1:numel(suite.cases)
    for cr = suite.cases(k).criteria
        if isempty(cr.limit), unset = unset + 1; end
    end
end
fprintf("\n%d criteria carry no numeric limit. They are project or interconnection-agreement\n" + ...
    "values; inventing them would be the most dangerous thing this harness could do.\n", unset);

fprintf("\n%s\n", RULE);
disp("SUMMARY");
disp(RULE);
fprintf("  gates, as handed over   : %s\n", blockedOrPassed(rep));
fprintf("  gates, after remediation: %s\n", blockedOrPassed(rep2));
for k = ["A", "B", "C", "D"]
    fprintf("  identification %s        : %s\n", k, ident.(k).verdict.Value);
end
end

function s = blockedOrPassed(rep)
if rep.failed(), s = "BLOCKED"; else, s = "passed"; end
end

% -------------------------------------------------------------------------
% Part 3: identification against known truth
% -------------------------------------------------------------------------

function results = runIdentification()
RP_TRUE = 0.05; TP_TRUE = 0.20; H_TRUE = 2.0;
% Two instrumentation classes, deliberately contrasted.
PMU = struct("dt_meas", 0.02, "t_end", 8.0, "sigma", 2.0e-4);       % ~0.01 Hz resolution at 50 Hz
HISTORIAN = struct("dt_meas", 1.0, "t_end", 20.0, "sigma", 1.0e-3); % ~0.05 Hz, 1 s scan
SUB = string(repmat('-', 1, 78));

    function [t, p, idx, y] = makeMeasurement(cls, ramp_limit, seed)
        [t, p] = mgtwin.loadStep(t_end=cls.t_end, dt=0.002);
        truth = mgtwin.simulateGfm(t, p, RP_TRUE, TP_TRUE, H_TRUE, ramp_limit_pu_s=ramp_limit);
        idx = (1:round(cls.dt_meas / 0.002):numel(t))';
        rs = RandStream("mt19937ar", "Seed", seed);
        y = truth(idx, 1) + cls.sigma * randn(rs, numel(idx), 1);
    end

    function report(label, blurb, res, truth, n)
        fprintf("\n%s\n%s\n%s\n\n", SUB, label, blurb);
        disp(res.render());
        fprintf("  n = %d samples\n", n);
        tn = string(fieldnames(truth))';
        parts = arrayfun(@(nm) sprintf("%s=%g", nm, truth.(nm)), tn);
        fprintf("  truth: %s\n", strjoin(parts, ", "));
        for k = 1:numel(res.names)
            nm = res.names(k);
            if isfield(truth, nm)
                err = 100.0 * (res.theta(k) - truth.(nm)) / truth.(nm);
                fprintf("    %-10s %+8.1f%% from truth\n", nm, err);
            end
        end
    end

results = struct();

% -- A: PMU-rate, inertia taken from datasheet ---------------------------
[t, p, idx, y] = makeMeasurement(PMU, [], 7);
res = mgtwin.identify(predictor(t, p, idx, struct("h_sec", H_TRUE)), y, ...
    struct("rp_pu", 0.03, "tp_sec", 0.40), struct("rp_pu", [0.005, 0.20], "tp_sec", [0.01, 2.0]));
report("CASE A  PMU-rate data, two parameters, correct model form", ...
    "Virtual inertia fixed at its datasheet value. Baseline for the rest.", ...
    res, struct("rp_pu", RP_TRUE, "tp_sec", TP_TRUE), numel(idx));
results.A = res;

% -- B: PMU-rate, inertia also estimated ---------------------------------
res = mgtwin.identify(predictor(t, p, idx, struct()), y, ...
    struct("rp_pu", 0.03, "tp_sec", 0.40, "h_sec", 1.0), ...
    struct("rp_pu", [0.005, 0.20], "tp_sec", [0.01, 2.0], "h_sec", [0.05, 20.0]));
report("CASE B  same data, virtual inertia estimated as well", ...
    "The transfer function is omega/P = -rp / [(1 + tp*s)(1 + 2*H*rp*s)], so the" + newline + ...
    "two lags enter symmetrically and at 2*H*rp = tp = 0.2 s they are nearly" + newline + ...
    "interchangeable. The least-determined direction below is that trade, and it" + newline + ...
    "shows up with the right shape: tp and h_sec with opposite signs. At PMU rate" + newline + ...
    "there is still enough information to separate them, so the honest verdict is" + newline + ...
    "IDENTIFIED with the trade-off named -- not a refusal.", ...
    res, struct("rp_pu", RP_TRUE, "tp_sec", TP_TRUE, "h_sec", H_TRUE), numel(idx));
results.B = res;

% -- C: same plant, historian-grade data ---------------------------------
[t, p, idx, y] = makeMeasurement(HISTORIAN, [], 7);
res = mgtwin.identify(predictor(t, p, idx, struct()), y, ...
    struct("rp_pu", 0.03, "tp_sec", 0.40, "h_sec", 1.0), ...
    struct("rp_pu", [0.005, 0.20], "tp_sec", [0.01, 2.0], "h_sec", [0.05, 20.0]));
report("CASE C  identical plant and model, historian-grade measurement", ...
    "1 s scan rate, 0.05 Hz resolution -- i.e. what actually comes out of a SCADA" + newline + ...
    "historian. The 0.2 s transient falls between samples. Droop is still" + newline + ...
    "recoverable because it is a steady-state gain; the dynamics are not" + newline + ...
    "recoverable at all, and the optimiser happily drives tp onto its bound." + newline + ...
    "The verdict is a property of the EXPERIMENT, not of the model. This is the" + newline + ...
    "gate doing the one job that matters: returning an instrumentation" + newline + ...
    "requirement instead of a number.", ...
    res, struct("rp_pu", RP_TRUE, "tp_sec", TP_TRUE, "h_sec", H_TRUE), numel(idx));
results.C = res;

% -- D: model-form mismatch ----------------------------------------------
[t, p, idx, y] = makeMeasurement(PMU, 0.30, 11);
res = mgtwin.identify(predictor(t, p, idx, struct("h_sec", H_TRUE)), y, ...
    struct("rp_pu", 0.03, "tp_sec", 0.40), struct("rp_pu", [0.005, 0.20], "tp_sec", [0.01, 2.0]));
report("CASE D  truth has a ramp-rate limit the library model does not contain", ...
    "A real BESS ramp limit of 0.30 pu/s against a 0.30 pu step. The fitted model" + newline + ...
    "is the same well-conditioned two-parameter form as case A, so the Fisher" + newline + ...
    "intervals come back tight -- and they are worthless. Only the residual" + newline + ...
    "structure reveals it, which is why whiteness is tested first and overrides" + newline + ...
    "the intervals. An identifier that reported 1.5% on tp here would have" + newline + ...
    "converted an unknown into a false certainty.", ...
    res, struct("rp_pu", RP_TRUE, "tp_sec", TP_TRUE), numel(idx));
results.D = res;
end

function predict = predictor(t, p, idx, fixed)
% Library-form predictor; parameters not in theta are taken from FIXED.
predict = @(theta) predictGfm(t, p, idx, theta, fixed);
end

function yhat = predictGfm(t, p, idx, theta, fixed)
get = @(nm) getParam(theta, fixed, nm);
out = mgtwin.simulateGfm(t, p, get("rp_pu"), get("tp_sec"), get("h_sec"));
yhat = out(idx, 1);
end

function v = getParam(theta, fixed, nm)
if isfield(theta, nm), v = theta.(nm); else, v = fixed.(nm); end
end
