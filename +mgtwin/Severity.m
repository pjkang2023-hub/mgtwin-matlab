classdef Severity
    enumeration
        PASS ("pass")
        WARN ("warn")
        FAIL ("fail")
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = Severity(v)
            obj.Value = v;
        end
        function r = rank(obj)
            %RANK Sort key: FAIL first, then WARN, then PASS.
            switch obj
                case mgtwin.Severity.FAIL, r = 0;
                case mgtwin.Severity.WARN, r = 1;
                otherwise, r = 2;
            end
        end
    end
end
