classdef CaseStatus
    enumeration
        EXECUTED ("executed")
        BLOCKED  ("blocked")     % prerequisites failed (gate findings attached)
        DEFERRED ("deferred")    % exceeds available model tier (reason attached)
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = CaseStatus(v)
            obj.Value = v;
        end
    end
end
