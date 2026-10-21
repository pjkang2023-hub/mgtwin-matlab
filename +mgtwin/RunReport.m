classdef RunReport < handle
    %RUNREPORT The runner's deliverable: the thing a customer eventually signs.
    %
    %   Honesty rules (enforced by the runner, rendered here):
    %   1. A criterion with no numeric limit is UNEVALUATED, never pass/fail.
    %   2. A case whose prerequisites fail is BLOCKED, with gate findings attached.
    %   3. A case whose physics exceeds the available model tier is DEFERRED
    %      with the tier named.
    %   4. Every executed case records the PROVENANCE of the dynamic
    %      parameters it used; a PASS on assumed parameters says so.
    properties
        suite_edition (1,1) string = ""
        site_id (1,1) string = ""
        results (1,:) mgtwin.TestResult = mgtwin.TestResult.empty(1,0)
    end
    methods
        function obj = RunReport(suite_edition, site_id)
            if nargin == 0, return; end
            obj.suite_edition = suite_edition;
            obj.site_id = site_id;
        end
        function add(obj, r)
            obj.results(end+1) = r;
        end
        function r = byCaseId(obj, id)
            for k = 1:numel(obj.results)
                if obj.results(k).test_case.id == id, r = obj.results(k); return; end
            end
            error("mgtwin:KeyError", "no result for case '%s'", id);
        end
        function c = counts(obj)
            c = struct("executed", 0, "blocked", 0, "deferred", 0, ...
                       "pass", 0, "fail", 0, "indeterminate", 0);
            for k = 1:numel(obj.results)
                r = obj.results(k);
                c.(r.status.Value) = c.(r.status.Value) + 1;
                if r.status == mgtwin.CaseStatus.EXECUTED
                    c.(r.verdict.Value) = c.(r.verdict.Value) + 1;
                end
            end
        end
        function s = render(obj)
            lines = [sprintf("Test run: suite edition %s on site %s", obj.suite_edition, obj.site_id), ...
                     string(repmat('-', 1, 78))];
            for k = 1:numel(obj.results)
                lines(end+1) = obj.results(k).render(); %#ok<AGROW>
                lines(end+1) = ""; %#ok<AGROW>
            end
            c = obj.counts();
            lines(end+1) = sprintf("summary: %d executed (%d pass, %d fail, %d indeterminate), %d blocked, %d deferred", ...
                c.executed, c.pass, c.fail, c.indeterminate, c.blocked, c.deferred);
            s = strjoin(lines, newline);
        end
    end
end
