classdef TestResult < handle
    %TESTRESULT Result of one test case on one island. Handle class: the
    %   runner fills it in incrementally.
    %   The Python field `case` is `test_case` here (MATLAB keyword).
    properties
        test_case (1,1) mgtwin.TestCase = mgtwin.TestCase()
        island_id (1,1) string = ""
        status (1,1) mgtwin.CaseStatus = mgtwin.CaseStatus.EXECUTED
        verdict (1,1) mgtwin.CaseVerdict = mgtwin.CaseVerdict.NONE
        metrics (1,:) mgtwin.MetricValue = mgtwin.MetricValue.empty(1,0)
        criteria (1,:) mgtwin.CriterionResult = mgtwin.CriterionResult.empty(1,0)
        blocking_findings (:,1) mgtwin.Finding = mgtwin.Finding.empty(0,1)
        defer_reason (1,1) string = ""
        provenance (1,1) mgtwin.ParamProvenance = mgtwin.ParamProvenance.ASSUMED
        provenance_detail (1,1) string = ""
        notes (1,:) string = string.empty(1,0)
    end
    methods
        function obj = TestResult(test_case, island_id, status)
            if nargin == 0, return; end
            obj.test_case = test_case;
            obj.island_id = island_id;
            if nargin >= 3, obj.status = status; end
        end
        function m = metric(obj, name)
            %METRIC Look up a reported metric by name.
            for k = 1:numel(obj.metrics)
                if obj.metrics(k).metric == name, m = obj.metrics(k); return; end
            end
            error("mgtwin:KeyError", "no metric '%s' on %s", name, obj.test_case.id);
        end
        function s = render(obj)
            lines = sprintf("  %-10s [%s] %s", obj.test_case.id, obj.island_id, obj.test_case.title);
            if obj.status == mgtwin.CaseStatus.BLOCKED
                lines(end+1) = "    status: BLOCKED -- prerequisites failed";
                for k = 1:numel(obj.blocking_findings)
                    f = obj.blocking_findings(k);
                    lines(end+1) = sprintf("      gate %s [%s]: %s", f.gate, f.scope, f.message); %#ok<AGROW>
                end
                s = strjoin(lines, newline);
                return;
            end
            if obj.status == mgtwin.CaseStatus.DEFERRED
                lines(end+1) = "    status: DEFERRED -- " + obj.defer_reason;
                s = strjoin(lines, newline);
                return;
            end
            detail = "";
            if strlength(obj.provenance_detail) > 0
                detail = " (" + obj.provenance_detail + ")";
            end
            lines(end+1) = sprintf("    status: EXECUTED   verdict: %s   parameters: %s%s", ...
                upper(obj.verdict.Value), obj.provenance.Value, detail);
            if obj.provenance == mgtwin.ParamProvenance.ASSUMED && obj.verdict == mgtwin.CaseVerdict.PASS
                lines(end+1) = "    NOTE: PASS is conditional on assumed dynamic parameters; " + ...
                    "identify from response data before relying on it.";
            end
            for k = 1:numel(obj.metrics)
                m = obj.metrics(k);
                note = "";
                if strlength(m.note) > 0, note = "   (" + m.note + ")"; end
                lines(end+1) = sprintf("      %-32s %.4g %s%s", m.metric, m.value, m.unit, note); %#ok<AGROW>
            end
            if ~isempty(obj.criteria)
                lines(end+1) = "    criteria:";
                for k = 1:numel(obj.criteria)
                    lines(end+1) = obj.criteria(k).render(); %#ok<AGROW>
                end
            end
            for k = 1:numel(obj.notes)
                lines(end+1) = "    note: " + obj.notes(k); %#ok<AGROW>
            end
            s = strjoin(lines, newline);
        end
    end
end
