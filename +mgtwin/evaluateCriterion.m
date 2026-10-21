function r = evaluateCriterion(c, measured)
%EVALUATECRITERION Judge one criterion. A criterion with no numeric limit or
%   no measurement is UNEVALUATED, never pass/fail: the limits live in the
%   interconnection agreement or the project spec; a harness that invents
%   them is manufacturing compliance.
if isempty(measured) || isempty(c.limit)
    r = mgtwin.CriterionResult(c, measured, false, []);
    return;
end
switch c.comparator
    case "<=",     ok = measured <= c.limit;
    case "<",      ok = measured < c.limit;
    case ">=",     ok = measured >= c.limit;
    case ">",      ok = measured > c.limit;
    case "within", ok = abs(measured) <= c.limit;
    otherwise
        error("mgtwin:ValueError", "unknown comparator '%s'", c.comparator);
end
r = mgtwin.CriterionResult(c, measured, true, ok);
end
