function suite = loadSuite(name)
%LOADSUITE Load a test suite from +mgtwin/specs/<name>.json.
%
%   Why data and not code: P2030.8 is under revision (Active PAR approved
%   2026-03-26 superseding 2030.8-2018). A harness that hard-codes the 2018
%   test taxonomy rots the day the revision publishes. Test cases therefore
%   live in versioned data files tagged with the edition they belong to.
%   (The Python package uses YAML; MATLAB R2024a has no YAML reader, so the
%   MATLAB port carries the same content as JSON. The original YAML is kept
%   alongside for provenance.)
%
%   Copyright: no normative text from any IEEE standard is reproduced. The
%   `clause` field is deliberately empty and must be populated by the user
%   from their own licensed copy.
arguments
    name (1,1) string = "ieee2030_8_2018"
end
specDir = mgtwin.internal.specDir();
path = fullfile(specDir, name + ".json");
if ~isfile(path)
    error("mgtwin:FileNotFound", "no spec '%s'; available: %s", name, strjoin(mgtwin.availableSuites(), ", "));
end
raw = jsondecode(fileread(path));
rawCases = raw.cases;
if isstruct(rawCases)
    rawCases = num2cell(rawCases);
end
cases = mgtwin.TestCase.empty(1,0);
for k = 1:numel(rawCases)
    c = rawCases{k};
    rawCrit = c.criteria;
    if isstruct(rawCrit), rawCrit = num2cell(rawCrit); end
    crit = mgtwin.Criterion.empty(1,0);
    for j = 1:numel(rawCrit)
        cr = rawCrit{j};
        crit(j) = mgtwin.Criterion( ...
            metric=string(cr.metric), unit=string(cr.unit), comparator=string(cr.comparator), ...
            limit=getOr(cr, "limit", []), limit_source=string(getOr(cr, "limit_source", "project")), ...
            notes=string(getOr(cr, "notes", "")));
    end
    meas = getOr(c, "measurements", {});
    if ischar(meas), meas = {meas}; end
    cases(k) = mgtwin.TestCase( ...
        id=string(c.id), core_function=mgtwin.CoreFunction.fromValue(c.function), ...
        title=string(c.title), edition=string(c.edition), clause=string(getOr(c, "clause", "")), ...
        initial_condition=strtrim(string(c.initial_condition)), ...
        initiating_event=strtrim(string(c.initiating_event)), ...
        measurements=string(meas), criteria=crit, ...
        requires_island_config=logical(getOr(c, "requires_island_config", true)), ...
        requires_emt=logical(getOr(c, "requires_emt", false)), ...
        notes=strtrim(string(getOr(c, "notes", ""))));
end
suite = mgtwin.TestSuite(edition=string(raw.edition), source=string(raw.source), ...
    disclaimer=strtrim(string(raw.disclaimer)), cases=cases);
end

function v = getOr(s, f, default)
if isfield(s, f) && ~isempty(s.(f))
    v = s.(f);
else
    v = default;
end
end
