classdef CoreFunction
    %COREFUNCTION Controller function families a microgrid controller test suite covers.
    enumeration
        DISPATCH            ("dispatch")
        PLANNED_ISLANDING   ("planned_islanding")
        UNPLANNED_ISLANDING ("unplanned_islanding")
        RECONNECTION        ("reconnection")
        BLACK_START         ("black_start")
        STEADY_STATE        ("steady_state")
        POWER_QUALITY       ("power_quality")
        PROTECTION          ("protection")
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = CoreFunction(v)
            obj.Value = v;
        end
    end
    methods (Static)
        function e = fromValue(v)
            e = mgtwin.internal.enumFromValue("mgtwin.CoreFunction", v);
        end
    end
end
