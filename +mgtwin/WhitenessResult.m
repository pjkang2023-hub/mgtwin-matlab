classdef WhitenessResult
    %WHITENESSRESULT Residual whiteness diagnostics (Ljung-Box + runs test).
    properties
        ljung_box_q (1,1) double = NaN
        ljung_box_p (1,1) double = NaN
        lag1_autocorr (1,1) double = NaN
        runs_z (1,1) double = NaN
        runs_p (1,1) double = NaN
        white (1,1) logical = false
    end
    methods
        function obj = WhitenessResult(q, p_lb, lag1, z, p_runs, white)
            if nargin == 0, return; end
            obj.ljung_box_q = q; obj.ljung_box_p = p_lb; obj.lag1_autocorr = lag1;
            obj.runs_z = z; obj.runs_p = p_runs; obj.white = white;
        end
        function s = render(obj)
            if obj.white, verdict = "white"; else, verdict = "STRUCTURED"; end
            s = sprintf("residuals: %s | Ljung-Box Q=%.1f (p=%.2e), lag-1 rho=%+.3f, runs z=%+.1f (p=%.2e)", ...
                verdict, obj.ljung_box_q, obj.ljung_box_p, obj.lag1_autocorr, obj.runs_z, obj.runs_p);
        end
    end
end
