classdef AngleRef
    %ANGLEREF Angle reference for phasor quantities.
    enumeration
        COSINE ("cosine")   % v = V*cos(wt + th)
        SINE   ("sine")     % v = V*sin(wt + th)
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = AngleRef(v)
            obj.Value = v;
        end
    end
end
