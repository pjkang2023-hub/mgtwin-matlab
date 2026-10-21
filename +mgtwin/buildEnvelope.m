function env = buildEnvelope(site, opts)
%BUILDENVELOPE Declare the validity envelope of a Site from its gates, its
%   identification records and the protection studies run on its states.
%
%   env = mgtwin.buildEnvelope(site, identifications=recs, report=rep, protection_studies=studies)
%
%   A studied state's protection is judged by the study: OUTSIDE if it
%   fails, INSIDE if it passed on identified models, PROVISIONAL if on
%   assumed ones; a state no study covers keeps the gates' screening,
%   PROVISIONAL at best.
%
%   See also mgtwin.Envelope, mgtwin.IdentificationRecord, mgtwin.ProtectionStudyRecord.
arguments
    site (1,1) mgtwin.Site
    opts.identifications (1,:) mgtwin.IdentificationRecord = mgtwin.IdentificationRecord.empty(1,0)
    opts.report = []
    opts.protection_studies (1,:) mgtwin.ProtectionStudyRecord = mgtwin.ProtectionStudyRecord.empty(1,0)
end
import mgtwin.Phenomenon mgtwin.Support
if isempty(opts.report), report = mgtwin.runAllGates(site); else, report = opts.report; end
ids = opts.identifications;
idList = string({ids.source_id});
unknown = sort(setdiff(idList, site.sourceIds()));
if ~isempty(unknown)
    error("mgtwin:ValueError", "identification records for unknown sources ['%s']", strjoin(unknown, "', '"));
end
islandIds = string({site.islands.id});
studies = opts.protection_studies;
unknown = sort(setdiff(string({studies.state_id}), islandIds));
if ~isempty(unknown)
    error("mgtwin:ValueError", "protection studies for states the Site does not enumerate: ['%s']", strjoin(unknown, "', '"));
end

% Which gate's FAIL takes a state outside which phenomena. A forming FAIL takes it out of all.
allPh = enumeration("mgtwin.Phenomenon")';
gatePh = dictionary(["loading", "protection", "grounding", "energisation", "forming"], ...
    {[Phenomenon.LOADING, Phenomenon.FREQUENCY], Phenomenon.PROTECTION, ...
     [Phenomenon.GROUNDING, Phenomenon.PROTECTION], Phenomenon.ENERGISATION, allPh});

siteWide = string.empty(1,0);
perState = dictionary(string.empty, cell.empty);
for k = 1:numel(report.findings)
    f = report.findings(k);
    if f.severity ~= mgtwin.Severity.FAIL, continue; end
    state = extractBefore(f.scope + "/", "/");
    if ismember(state, islandIds)
        if isKey(perState, state), v = perState{state}; else, v = mgtwin.Finding.empty(0,1); end
        perState{state} = [v; f];
    elseif ismember(f.gate, ["units", "protection"]) || state == site.id
        siteWide(end+1) = f.gate + ": " + f.message; %#ok<AGROW>
    end
end

srcIds = [string({site.machines.id}), string({site.converters.id})];
srcMva = [[site.machines.s_rated_mva], [site.converters.s_rated_mva]];
isStore = [false(1, numel(site.machines)), arrayfun(@(c) ~isempty(c.energy_mwh), site.converters')];
states = mgtwin.StateEnvelope.empty(1,0);
for k = 1:numel(site.islands)
    isl = site.islands(k);
    here = isl.energized_source_ids(ismember(isl.energized_source_ids, srcIds));
    [~, loc] = ismember(here, srcIds);
    excluded = dictionary(string.empty, cell.empty);
    if isKey(perState, isl.id)
        fs = perState{isl.id};
        for j = 1:numel(fs)
            f = fs(j);
            if ~isKey(gatePh, f.gate), continue; end
            for ph = gatePh{f.gate}
                if isKey(excluded, ph.Value), v = excluded{ph.Value}; else, v = string.empty(1,0); end
                excluded{ph.Value} = [v, f.gate + ": " + f.message];
            end
        end
    end
    states(end+1) = mgtwin.StateEnvelope(state_id=isl.id, grid_connected=isl.grid_connected, sources=here, ...
        rating_mva=sum(srcMva(loc)), sustained_mva=sum(srcMva(loc(~isStore(loc)))), excluded=excluded); %#ok<AGROW>
end

isGfm = arrayfun(@(c) c.control ~= mgtwin.ConverterControl.GFL, site.converters);
gfm = [string({site.converters(isGfm).id}), string({site.machines.id})];
assumed = sort(gfm(~ismember(gfm, idList)));
rtAssumed = sort(string({site.converters(arrayfun(@(c) ~c.params.ride_through_identified, site.converters)).id}));
inrushAssumed = any(arrayfun(@(t) ~t.inrush_identified, site.transformers));
anyAssumed = ~isempty(assumed) || any(arrayfun(@(r) ~r.identified(), ids));

phen = [Phenomenon.LOADING, Phenomenon.FREQUENCY, Phenomenon.PROTECTION, Phenomenon.GROUNDING, ...
        Phenomenon.ENERGISATION, Phenomenon.VOLTAGE, Phenomenon.EMT, Phenomenon.DISPATCH, Phenomenon.RECONNECTION];
sup = repmat(Support.SUPPORTED, 1, 9); notes = strings(1, 9);
notes(1) = "ratings, not a load flow: a pass is necessary, not sufficient";
if anyAssumed, sup(2) = Support.PROVISIONAL; notes(2) = "aggregate RMS model on assumed dynamic parameters";
else, notes(2) = "aggregate RMS model on identified parameters"; end
if isempty(studies)
    if ~isempty(rtAssumed)
        sup(3) = Support.PROVISIONAL; notes(3) = "screening on assumed current limits; settings need a protection study";
    else
        notes(3) = "screening; settings need a protection study";
    end
else
    if ~isempty(rtAssumed), sup(3) = Support.PROVISIONAL; end
    notes(3) = sprintf("protection studies for %d of %d states; the rest screened only", numel(studies), numel(site.islands));
end
notes(4) = "zero-sequence topology; SLG overvoltage on radial feeders only";
if inrushAssumed, sup(5) = Support.PROVISIONAL; notes(5) = "static check on assumed inrush multiples";
else, notes(5) = "static check; waveforms need EMT"; end
% Phenomena outside this package's tier, and what answers them.
sup(6:9) = Support.EXCLUDED;
notes(6) = "no network solver here by design: pandapower or OpenDSS";
notes(7) = "an EMT study (point-on-wave, remanence, harmonics, sub-cycle current limiting)";
notes(8) = "an EMS dispatch model (the test runner defers DISP cases)";
notes(9) = "a synchroniser model (the test runner defers REC cases)";

undeclared = "frequency and voltage ranges over which the dynamic models hold (no source records them)";
if isempty(ids)
    undeclared(end+1) = "load-step amplitudes: no identification records, so no identified range";
end
if any([site.islands.grid_connected])
    undeclared(end+1) = "grid strength at the point of interconnection (grid-connected states)";
end

env = mgtwin.Envelope();
env.site_id = site.id; env.version = mgtwin.version();
env.phenomena = phen; env.support = sup; env.notes = notes;
env.states = states; env.site_wide_fails = siteWide;
env.identifications = ids; env.assumed_sources = assumed; env.ride_through_assumed = rtAssumed;
env.undeclared = undeclared; env.protection_studies = studies;
end
