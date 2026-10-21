function v = judge(criteria_results)
%JUDGE Case verdict from its criterion results.
%   INDETERMINATE when nothing could be evaluated; FAIL if any evaluated
%   criterion failed; else PASS.
if isempty(criteria_results)
    v = mgtwin.CaseVerdict.INDETERMINATE;
    return;
end
evaluated = criteria_results([criteria_results.evaluated]);
if isempty(evaluated)
    v = mgtwin.CaseVerdict.INDETERMINATE;
    return;
end
for k = 1:numel(evaluated)
    if ~evaluated(k).passed
        v = mgtwin.CaseVerdict.FAIL;
        return;
    end
end
v = mgtwin.CaseVerdict.PASS;
end
