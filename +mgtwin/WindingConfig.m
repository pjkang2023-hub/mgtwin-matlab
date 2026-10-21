classdef WindingConfig
    enumeration
        DELTA          ("delta")
        WYE_GROUNDED   ("wye_grounded")
        WYE_UNGROUNDED ("wye_ungrounded")
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = WindingConfig(v)
            obj.Value = v;
        end
    end
end
