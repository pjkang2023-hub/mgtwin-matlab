function c = identifyConstants()
%IDENTIFYCONSTANTS Thresholds of the identification gate.
%   REL_SE_LIMIT     relative standard error above which a parameter is
%                    treated as not pinned down
%   COND_LIMIT       condition number of the scaled sensitivity matrix above
%                    which the parameter set is practically unidentifiable
%   WHITENESS_ALPHA  significance level for the residual whiteness tests
%   CONSISTENCY_K    cross-experiment spread beyond this many combined
%                    standard errors is treated as operating-point dependence
%   CONSISTENCY_REL_FLOOR relative floor so ultra-tight fits don't flag ppm
c = struct( ...
    "REL_SE_LIMIT", 0.20, ...
    "COND_LIMIT", 1.0e3, ...
    "WHITENESS_ALPHA", 0.01, ...
    "CONSISTENCY_K", 4.0, ...
    "CONSISTENCY_REL_FLOOR", 0.03);
end
