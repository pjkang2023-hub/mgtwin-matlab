classdef CaseVerdict
    enumeration
        PASS          ("pass")           % every evaluated criterion passed
        FAIL          ("fail")           % at least one evaluated criterion failed
        INDETERMINATE ("indeterminate")  % measured, but no limits to compare
        NONE          ("none")           % not executed
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = CaseVerdict(v)
            obj.Value = v;
        end
    end
end
