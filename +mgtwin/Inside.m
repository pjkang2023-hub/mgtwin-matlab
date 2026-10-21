classdef Inside
    %INSIDE The envelope's answer to a question.
    enumeration
        INSIDE ("inside")
        PROVISIONAL ("provisional")
        OUTSIDE ("outside")
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = Inside(v)
            obj.Value = v;
        end
    end
end
