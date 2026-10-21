classdef Finding
    %FINDING One gate result.
    %   f = mgtwin.Finding(gate, severity, message, scope, remedy)
    properties
        gate (1,1) string = ""
        severity (1,1) mgtwin.Severity = mgtwin.Severity.PASS
        message (1,1) string = ""
        scope (1,1) string = ""      % island id, component id, etc.
        remedy (1,1) string = ""
    end
    methods
        function obj = Finding(gate, severity, message, scope, remedy)
            if nargin == 0, return; end
            obj.gate = gate;
            obj.severity = severity;
            obj.message = message;
            if nargin >= 4, obj.scope = scope; end
            if nargin >= 5, obj.remedy = remedy; end
        end
    end
end
