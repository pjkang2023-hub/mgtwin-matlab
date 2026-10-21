classdef Support
    %SUPPORT How far this package's tier represents a phenomenon.
    enumeration
        SUPPORTED ("supported")
        PROVISIONAL ("provisional")
        EXCLUDED ("excluded")
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = Support(v)
            obj.Value = v;
        end
    end
end
