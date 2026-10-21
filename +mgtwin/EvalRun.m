classdef EvalRun
    %EVALRUN One (scenario, seed) identification run scored into a confusion cell.
    properties
        scenario (1,1) string = ""
        mismatch (1,1) logical = false
        seed (1,1) double = NaN
        verdict (1,1) mgtwin.Verdict = mgtwin.Verdict.NOT_IDENTIFIABLE
        bias struct = struct()   % name -> relative bias
        cell (1,1) string = ""   % true_confidence / false_confidence / true_refusal / over_refusal
    end
    methods
        function obj = EvalRun(scenario, mismatch, seed, verdict, bias, cell)
            if nargin == 0, return; end
            obj.scenario = scenario; obj.mismatch = mismatch; obj.seed = seed;
            obj.verdict = verdict; obj.bias = bias; obj.cell = cell;
        end
        function b = maxBias(obj)
            vals = struct2array(obj.bias);
            b = max(abs(vals));
        end
    end
end
