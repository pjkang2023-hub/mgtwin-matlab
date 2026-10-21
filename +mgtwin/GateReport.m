classdef GateReport < handle
    %GATEREPORT Accumulates Findings from one or more gates. Handle class so
    %   gates can append in place; use copy semantics deliberately.
    properties
        findings (:,1) mgtwin.Finding = mgtwin.Finding.empty(0,1)
    end
    methods
        function add(obj, f)
            obj.findings(end+1, 1) = f;
        end
        function tf = failed(obj)
            tf = any(obj.severities() == mgtwin.Severity.FAIL);
        end
        function tf = warned(obj)
            tf = any(obj.severities() == mgtwin.Severity.WARN);
        end
        function fs = bySeverity(obj, sev)
            fs = obj.findings(obj.severities() == sev);
        end
        function fs = byGate(obj, gate)
            if isempty(obj.findings)
                fs = obj.findings; return;
            end
            fs = obj.findings(string({obj.findings.gate}) == gate);
        end
        function obj = extend(obj, other)
            obj.findings = [obj.findings; other.findings];
        end
        function s = render(obj)
            if isempty(obj.findings)
                s = "no findings";
                return;
            end
            [~, order] = sort(arrayfun(@(f) f.severity.rank(), obj.findings));  % stable sort
            lines = string.empty(1,0);
            for k = order'
                f = obj.findings(k);
                tag = upper(f.severity.Value);
                scope = "";
                if strlength(f.scope) > 0, scope = " [" + f.scope + "]"; end
                lines(end+1) = sprintf("%-4s %s%s: %s", tag, f.gate, scope, f.message); %#ok<AGROW>
                if strlength(f.remedy) > 0
                    lines(end+1) = "       -> " + f.remedy; %#ok<AGROW>
                end
            end
            s = strjoin(lines, newline);
        end
    end
    methods (Access = private)
        function s = severities(obj)
            if isempty(obj.findings)
                s = mgtwin.Severity.empty(0,1);
            else
                s = [obj.findings.severity]';
            end
        end
    end
end
