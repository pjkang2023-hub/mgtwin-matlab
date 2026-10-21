classdef GroundingKind
    enumeration
        UNGROUNDED      ("ungrounded")
        SOLID           ("solidly_grounded")
        LOW_RESISTANCE  ("low_resistance_grounded")
        HIGH_RESISTANCE ("high_resistance_grounded")
        REACTANCE       ("reactance_grounded")
        RESONANT        ("resonant_grounded")
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = GroundingKind(v)
            obj.Value = v;
        end
    end
end
