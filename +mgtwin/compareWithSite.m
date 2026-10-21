function out = compareWithSite(rep, site, opts)
%COMPAREWITHSITE Set ingested entities against a composed Site.
%
%   out = mgtwin.compareWithSite(rep, site, identification_period_s=0.05)
%
%   Reports what the tags name that the Site lacks, what the Site holds that
%   no tag observes, and which sources cannot be identified from operating
%   data. A source needs P and F; IDENTIFICATION_PERIOD_S, if the caller
%   gives one, is the slowest sampling that still identifies its dynamics
%   (rung 4: a historian's 1 s is not; a PMU's is) - no default is assumed.
%   OUT is a struct array (kind, id, message).
arguments
    rep (1,1) mgtwin.IngestReport
    site (1,1) mgtwin.Site
    opts.identification_period_s double = []
end
out = struct("kind", {}, "id", {}, "message", {});
kinds = mgtwin.TagRule.KINDS;
inSite = dictionary(string.empty, cell.empty);
for kind = keys(kinds)'
    items = site.(kinds(kind));
    inSite{kind} = sort(string({items.id}));
end
for k = rep.sortedEntities()
    e = rep.entities(k);
    if ~ismember(e.id, inSite{e.kind})
        out(end+1) = struct("kind", e.kind, "id", e.id, "message", "telemetry for equipment the Site does not hold"); %#ok<AGROW>
    end
end
for kind = ["converter", "machine", "switch", "load"]
    for eid = inSite{kind}
        if isempty(rep.entityIndex(kind, eid))
            out(end+1) = struct("kind", kind, "id", eid, "message", "in the Site, but no tag observes it"); %#ok<AGROW>
        end
    end
end
for kind = ["converter", "machine"]
    for eid = inSite{kind}
        k = rep.entityIndex(kind, eid);
        if isempty(k), continue; end
        missing = string.empty(1,0);
        for m = ["P", "F"]
            if isempty(rep.measurementResult(k, m)), missing(end+1) = m; end %#ok<AGROW>
        end
        if ~isempty(missing)
            out(end+1) = struct("kind", kind, "id", eid, "message", ...
                "cannot be identified from operating data: no " + strjoin(missing, "/") + " tag"); %#ok<AGROW>
        elseif ~isempty(opts.identification_period_s)
            slow = string.empty(1,0);
            for m = ["P", "F"]
                T = rep.measurementResult(k, m).tag.sample_period_s;
                if isempty(T)
                    slow(end+1) = m + " at an unknown period"; %#ok<AGROW>
                elseif T > opts.identification_period_s
                    slow(end+1) = sprintf("%s at %g s", m, T); %#ok<AGROW>
                end
            end
            if ~isempty(slow)
                out(end+1) = struct("kind", kind, "id", eid, "message", sprintf("sampled too slowly to identify (needs <= %g s): %s", ...
                    opts.identification_period_s, strjoin(slow, ", "))); %#ok<AGROW>
            end
        end
    end
end
end
