classdef LoadModel
    enumeration
        ZIP            ("zip")
        CONSTANT_POWER ("constant_power")
        MOTOR          ("induction_motor")
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = LoadModel(v)
            obj.Value = v;
        end
    end
end
