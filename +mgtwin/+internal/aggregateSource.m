function src = aggregateSource(site, isl)
%AGGREGATESOURCE Largest grid-forming source sets the dynamics; ratings sum.
%
%   Returns a struct: s_mva, rp_pu, h_sec, tp_sec, provenance
%   (mgtwin.ParamProvenance), detail. Provenance is ASSUMED unless the lead
%   converter's params carry ride_through_identified.
srcs = {};
for k = 1:numel(isl.energized_source_ids)
    srcs{end+1} = site.source(isl.energized_source_ids(k)); %#ok<AGROW>
end
if isempty(srcs)
    error("mgtwin:ValueError", "island '%s' declares no energized sources", isl.id);
end
gfm = {};
for k = 1:numel(srcs)
    s = srcs{k};
    if isa(s, "mgtwin.SynchronousGen")
        gfm{end+1} = s; %#ok<AGROW>
    elseif isa(s, "mgtwin.Converter") && s.control ~= mgtwin.ConverterControl.GFL
        gfm{end+1} = s; %#ok<AGROW>
    end
end
if isempty(gfm)
    error("mgtwin:ValueError", "island '%s' has no grid-forming source; it cannot hold " + ...
        "frequency and no RMS islanding case is meaningful", isl.id);
end
ratings = cellfun(@(s) s.s_rated_mva, gfm);
[~, imax] = max(ratings);
lead = gfm{imax};
if isa(lead, "mgtwin.SynchronousGen")
    rp = lead.droop_pu; h = lead.h_sec; tp = 0.30;   % governor lag, assumed
    prov = mgtwin.ParamProvenance.ASSUMED;
    detail = sprintf("lead source %s: machine datasheet-class values", lead.id);
else
    p = lead.params;
    if isempty(p.p_f_droop_pu), rp = 0.05; else, rp = p.p_f_droop_pu; end
    if isempty(p.h_sec), h = 0.0; else, h = p.h_sec; end
    tp = p.tp_sec;
    if p.ride_through_identified
        prov = mgtwin.ParamProvenance.IDENTIFIED;
    else
        prov = mgtwin.ParamProvenance.ASSUMED;
    end
    detail = sprintf("lead source %s", lead.id);
end
src = struct( ...
    "s_mva", sum(ratings), ...
    "rp_pu", rp, ...
    "h_sec", max(h, 0.05), ...
    "tp_sec", tp, ...
    "provenance", prov, ...
    "detail", string(detail));
end
