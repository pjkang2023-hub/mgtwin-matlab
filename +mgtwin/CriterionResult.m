classdef CriterionResult
    %CRITERIONRESULT One criterion judged (or deliberately left unevaluated).
    properties
        criterion (1,1) mgtwin.Criterion = mgtwin.Criterion()
        measured double = []        % [] when not measured
        evaluated (1,1) logical = false
        passed logical = []         % [] when not evaluated
    end
    methods
        function obj = CriterionResult(criterion, measured, evaluated, passed)
            if nargin == 0, return; end
            obj.criterion = criterion; obj.measured = measured;
            obj.evaluated = evaluated; obj.passed = passed;
        end
        function s = render(obj)
            c = obj.criterion;
            if ~isempty(obj.measured)
                meas = sprintf("%.4g %s", obj.measured, c.unit);
            else
                meas = "-";
            end
            if ~obj.evaluated
                if isempty(c.limit)
                    lim = sprintf("no limit set (source: %s)", c.limit_source);
                else
                    lim = "not measured";
                end
                s = sprintf("      %-32s measured %-16s UNEVALUATED -- %s", c.metric, meas, lim);
                return;
            end
            if obj.passed, mark = "PASS"; else, mark = "FAIL"; end
            s = sprintf("      %-32s measured %-16s %s vs %s %g %s (%s)", ...
                c.metric, meas, mark, c.comparator, c.limit, c.unit, c.limit_source);
        end
    end
end
