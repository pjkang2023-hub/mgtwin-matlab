classdef ParamProvenance
    enumeration
        IDENTIFIED ("identified")  % from measured response, via identify()
        ASSUMED    ("assumed")     % datasheet, typical value, or guess
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = ParamProvenance(v)
            obj.Value = v;
        end
    end
end
