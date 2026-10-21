function rep = ingestTags(tags, rules)
%INGESTTAGS Stage 1: map a site's tag list to canonical entities by its rules.
%
%   rep = mgtwin.ingestTags(tags, rules)   % mgtwin.Tag array, mgtwin.TagRule array
%
%   A SCADA or historian export names its points by a site's own convention
%   ("PCS1.P_MW", "SOFC01_KW", "CB_TIE.POS"). Each tag is mapped to a
%   canonical entity (kind, id) and measurement (P, Q, S, V, I, F, SOC, POS,
%   TEMP) through rules the engineer writes for that site - none are built
%   in, because a naming convention guessed is a mapping invented. Every tag
%   comes back MATCHED, UNMATCHED (no rule, or a measurement code the rule
%   does not map), AMBIGUOUS (two rules disagree) or DUPLICATE, and every unit
%   is checked against the measurement's dimension and scaled to the
%   canonical unit (MW, Mvar, kV, kA, Hz, pu). Nothing unmatched is guessed.
%   Ingest does not compose topology: tags say what is measured, not what is
%   connected.
%
%   See also mgtwin.TagRule, mgtwin.readTags, mgtwin.loadRules, mgtwin.compareWithSite.
arguments
    tags (1,:) mgtwin.Tag
    rules (1,:) mgtwin.TagRule
end
import mgtwin.TagStatus
results = mgtwin.TagResult.empty(1,0);
entities = struct("kind", {}, "id", {}, "measurements", {});
for t = tags
    hits = {};
    for r = rules
        h = r.apply(t.tag);
        if ~isempty(h), hits{end+1} = h; end %#ok<AGROW>
    end
    if isempty(hits)
        results(end+1) = mgtwin.TagResult(tag=t, status=TagStatus.UNMATCHED, notes="no rule matches"); %#ok<AGROW>
        continue;
    end
    reprs = unique(cellfun(@(h) tupleRepr(h), hits));
    if numel(reprs) > 1
        results(end+1) = mgtwin.TagResult(tag=t, status=TagStatus.AMBIGUOUS, ...
            notes="rules disagree: [" + strjoin(sort(reprs), ", ") + "]"); %#ok<AGROW>
        continue;
    end
    h = hits{1};
    if strlength(h.meas) == 0
        if strlength(h.code) > 0, c = "'" + h.code + "'"; else, c = "None"; end
        results(end+1) = mgtwin.TagResult(tag=t, status=TagStatus.UNMATCHED, kind=h.kind, entity_id=h.id, ...
            notes="measurement code " + c + " is not in the rule's map"); %#ok<AGROW>
        continue;
    end
    [scale, notes] = checkUnit(h.meas, t.unit);
    k = [];
    if ~isempty(entities)
        k = find(string({entities.kind}) == h.kind & string({entities.id}) == h.id, 1);
    end
    if isempty(k)
        entities(end+1) = struct("kind", h.kind, "id", h.id, "measurements", dictionary(string.empty, double.empty)); %#ok<AGROW>
        k = numel(entities);
    end
    m = entities(k).measurements;
    if isKey(m, h.meas)
        prior = results(m(h.meas)).tag.tag;
        results(end+1) = mgtwin.TagResult(tag=t, status=TagStatus.DUPLICATE, kind=h.kind, entity_id=h.id, ...
            measurement=h.meas, scale=scale, notes=[notes, h.kind + " " + h.id + " " + h.meas + " already from " + prior]); %#ok<AGROW>
        continue;
    end
    results(end+1) = mgtwin.TagResult(tag=t, status=TagStatus.MATCHED, kind=h.kind, entity_id=h.id, ...
        measurement=h.meas, scale=scale, notes=notes); %#ok<AGROW>
    m(h.meas) = numel(results);
    entities(k).measurements = m;
end
rep = mgtwin.IngestReport(results, entities);
end

function s = tupleRepr(h)
% Python's repr of the (kind, id, measurement) tuple, None for a missing measurement.
if strlength(h.meas) > 0, m = "'" + h.meas + "'"; else, m = "None"; end
s = "('" + h.kind + "', '" + h.id + "', " + m + ")";
end

function [scale, notes] = checkUnit(meas, unit)
% unit (lower case) -> dimension and scale to the canonical unit
U = ["w", "kw", "mw", "var", "kvar", "mvar", "va", "kva", "mva", "v", "kv", "a", "ka", "hz", "%", "pu", ...
     "degc", "c", "", "bool", "state"];
UNITS = dictionary(U, ...
    ["power", "power", "power", "reactive", "reactive", "reactive", "apparent", "apparent", "apparent", ...
     "voltage", "voltage", "current", "current", "frequency", "fraction", "fraction", ...
     "temperature", "temperature", "state", "state", "state"]);
SCALE = dictionary(U, [1e-6, 1e-3, 1, 1e-6, 1e-3, 1, 1e-6, 1e-3, 1, 1e-3, 1, 1e-3, 1, 1, 0.01, 1, 1, 1, 1, 1, 1]);
% a voltage or current may be given per unit; it is then dimensionless but still that measurement
PU_ALLOWED = ["V", "I", "P", "Q", "S"];
u = replace(lower(strtrim(unit)), " ", "");
notes = string.empty(1,0);
if ~isKey(UNITS, u)
    scale = []; notes = "unit '" + unit + "' not recognised";
    return;
end
dim = UNITS(u); want = mgtwin.TagRule.MEASUREMENTS(meas);
if dim == want
    scale = SCALE(u);
elseif u == "pu" && ismember(meas, PU_ALLOWED)
    scale = 1.0; notes = "per unit: the base must be stated before it is used";
else
    scale = []; notes = "unit '" + unit + "' is " + dim + ", but " + meas + " is " + want;
end
end
