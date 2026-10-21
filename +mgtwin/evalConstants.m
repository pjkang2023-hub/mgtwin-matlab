function c = evalConstants()
%EVALCONSTANTS Tunables of the identification eval harness.
%   BIAS_LIMIT  5% relative error on any parameter = "badly wrong"
%   SMALL_STEP  second amplitude for the multi-experiment protocol: same
%               initial point, a deliberately smaller excursion, so
%               amplitude-dependent mechanisms (deadband, clamp, knee)
%               present different effective parameters.
c = struct("BIAS_LIMIT", 0.05, "SMALL_STEP", [0.20, 0.35]);
end
