function ok = rung4_identifiability_evals(seeds)
%RUNG4_IDENTIFIABILITY_EVALS Eval rung 4: adversarial identification battery.
%
%   The identifier is scored on REFUSAL BEHAVIOUR against plants containing
%   mechanisms the library form deliberately lacks. Parameter recovery is
%   not the metric; under mismatch the estimates are biased no matter what.
%   The metric is the confusion between verdict and consequence, whose one
%   forbidden cell is FALSE CONFIDENCE: a clean IDENTIFIED on estimates that
%   are badly wrong.
%
%   The battery runs twice, because the before/after is the finding:
%     SINGLE-EXPERIMENT protocol  -- catches shape-class mismatch, and is
%                                    structurally blind to amplitude-class
%                                    mismatch (~33% false confidence).
%     MULTI-AMPLITUDE protocol    -- two steps plus a consistency gate in
%                                    identifyMulti; 0% false confidence.
%
%   ok = rung4_identifiability_evals()      % 5 seeds, ~135 fits
%   ok = rung4_identifiability_evals(0:1)   % quicker
arguments
    seeds (1,:) double = 0:4
end
addpath(fullfile(fileparts(mfilename("fullpath")), ".."));
RULE = string(repmat('=', 1, 78));

disp(RULE);
disp("RUNG 4a  Single-experiment protocol (one step, whiteness + Fisher)");
disp(RULE);
t0 = tic;
rep_s = mgtwin.runBattery(seeds=seeds, protocol="single");
disp(rep_s.render());

fprintf("\n%s\n", RULE);
disp("RUNG 4b  Multi-amplitude protocol (two steps + consistency gate)");
disp(RULE);
rep_m = mgtwin.runBattery(seeds=seeds, protocol="multi");
disp(rep_m.render());

fprintf("\n%s\n", RULE);
disp("READING THE RESULT");
disp(RULE);
disp("Residual whiteness catches mismatch that changes the SHAPE of one" + newline + ...
    "trajectory (limiters mid-transient, extra lags). It cannot catch" + newline + ...
    "mismatch that only re-scales the trajectory -- deadband, clamps," + newline + ...
    "piecewise droop -- because on a single experiment those are" + newline + ...
    "observationally a different parameter value. The cure is not a" + newline + ...
    "stricter threshold (over-refusal would explode); it is a better" + newline + ...
    "EXPERIMENT: two amplitudes, one consistency demand. Note what stayed" + newline + ...
    "healthy across both protocols: nominal, noisy, quantized and the" + newline + ...
    "5 ms parasitic-lag probes all remain IDENTIFIED -- the gate got" + newline + ...
    "stricter about the right things without crying wolf." + newline + newline + ...
    "Product consequence: the commissioning test procedure must specify" + newline + ...
    "load steps at TWO amplitudes minimum, and the certified-parameter" + newline + ...
    "artifact must record the cross-amplitude spread alongside the" + newline + ...
    "estimates. One clean load-rejection trace is marketing, not" + newline + ...
    "identification.");
fprintf("\n[battery runtime %.0fs, %d fits scored]\n", toc(t0), numel(rep_s.runs) + numel(rep_m.runs));
ok = rep_m.falseConfidenceRate() == 0.0;
end
