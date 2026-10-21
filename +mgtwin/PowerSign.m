classdef PowerSign
    %POWERSIGN Which direction is positive real/reactive power at a terminal.
    %
    %   GENERATOR: positive = injection into the network (machines, converters).
    %   LOAD:      positive = withdrawal from the network (loads).
    %
    %   Declared per-component and checked at assembly. A BESS declared
    %   LOAD-positive while its droop gain assumes GENERATOR-positive produces a
    %   model that is unstable for reasons no one can find.
    enumeration
        GENERATOR ("generator")
        LOAD      ("load")
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = PowerSign(v)
            obj.Value = v;
        end
    end
end
