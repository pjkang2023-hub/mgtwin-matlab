classdef Envelope
    %ENVELOPE Stage 6: the declared validity envelope of a Site.
    %
    %   A twin that passes its gates is still only valid somewhere: in the
    %   states it enumerates, for the phenomena its tier represents, within
    %   the amplitudes its parameters were identified at. The envelope is the
    %   reviewable artifact that says where - and CHECK answers a question
    %   with INSIDE, PROVISIONAL or OUTSIDE plus the reasons, so a result can
    %   be quoted together with its limits.
    %
    %   Rules the envelope keeps:
    %     * No invented limits. A bound the Site and the identification
    %       records do not supply is UNDECLARED, never a typical value.
    %     * The gates bound the envelope. A state that FAILs a gate is OUTSIDE
    %       for the phenomena that gate speaks to; a site-wide FAIL (units)
    %       puts everything OUTSIDE until it clears.
    %     * Tier limits are named. Phenomena this package does not represent
    %       (EMT, network load flow, dispatch, synchronising) are OUTSIDE with
    %       the tool that answers them, as the runner defers them.
    %     * Assumed parameters make a result PROVISIONAL, not invalid; an
    %       amplitude beyond the identification experiments is an
    %       extrapolation and says so.
    %     * A protection study on a state supersedes the screening for it.
    %
    %   Build one with mgtwin.buildEnvelope.
    properties
        site_id (1,1) string = ""
        version (1,1) string = ""
        phenomena (1,:) mgtwin.Phenomenon = mgtwin.Phenomenon.empty(1,0)
        support (1,:) mgtwin.Support = mgtwin.Support.empty(1,0)
        notes (1,:) string = string.empty(1,0)          % aligned with phenomena
        states (1,:) mgtwin.StateEnvelope = mgtwin.StateEnvelope.empty(1,0)
        site_wide_fails (1,:) string = string.empty(1,0)
        identifications (1,:) mgtwin.IdentificationRecord = mgtwin.IdentificationRecord.empty(1,0)
        assumed_sources (1,:) string = string.empty(1,0)   % grid-forming sources with no identification record
        ride_through_assumed (1,:) string = string.empty(1,0)
        undeclared (1,:) string = string.empty(1,0)
        protection_studies (1,:) mgtwin.ProtectionStudyRecord = mgtwin.ProtectionStudyRecord.empty(1,0)
    end
    methods
        % -- the question -------------------------------------------------
        function [verdict, why] = check(obj, state_id, phenomenon, opts)
            %CHECK Is a result for this state and phenomenon (at this load,
            %   this step) inside the envelope?
            %   [verdict, why] = env.check("NORMAL", "frequency", load_mva=30, step_pu=0.3)
            arguments
                obj
                state_id (1,1) string
                phenomenon
                opts.load_mva double = []
                opts.step_pu double = []
            end
            if isa(phenomenon, "mgtwin.Phenomenon"), ph = phenomenon;
            else, ph = mgtwin.internal.enumFromValue("mgtwin.Phenomenon", phenomenon); end
            P = mgtwin.Phenomenon.PROTECTION;
            out = string.empty(1,0); prov = string.empty(1,0);
            if ~isempty(obj.site_wide_fails)
                out(end+1) = "site-wide gate FAILs must clear first: " + strjoin(obj.site_wide_fails(1:min(3, end)), "; ");
            end
            i = find(obj.phenomena == ph, 1);
            sup = obj.support(i); note = obj.notes(i);
            if sup == mgtwin.Support.EXCLUDED
                out(end+1) = ph.Value + " is outside this tier - " + note;
            end
            st = obj.stateById(state_id);
            study = obj.studyById(state_id);
            if isempty(st)
                out(end+1) = "state '" + state_id + "' is not enumerated in the Site: the twin says nothing about it";
            else
                excl = st.excludedFor(ph.Value);
                if ph == P && ~isempty(study) && study.passed
                    % the study computed the fault currents the screening only bounds from ratings
                    excl = excl(~startsWith(excl, "protection:"));
                end
                if ~isempty(excl)
                    out(end+1) = "the gates FAIL this state for " + ph.Value + ": " + strjoin(excl(1:min(3, end)), "; ");
                end
                if ~isempty(opts.load_mva) && ~st.grid_connected
                    if opts.load_mva > st.rating_mva + 1e-9
                        out(end+1) = sprintf("load %g MVA exceeds the state's source rating %g MVA", opts.load_mva, st.rating_mva);
                    elseif opts.load_mva > st.sustained_mva + 1e-9
                        prov(end+1) = sprintf("load %g MVA exceeds the sustained sources' %g MVA: valid only as long as the storage lasts", ...
                            opts.load_mva, st.sustained_mva);
                    end
                end
                if ph == mgtwin.Phenomenon.FREQUENCY || ph == P
                    for sid = st.sources
                        rec = obj.identificationFor(sid);
                        if ismember(sid, obj.assumed_sources)
                            prov(end+1) = sid + ": dynamic parameters assumed, not identified"; %#ok<AGROW>
                        elseif ~isempty(rec) && ~rec.identified()
                            prov(end+1) = sid + ": identification verdict " + rec.verdict; %#ok<AGROW>
                        elseif ~isempty(rec) && ~isempty(opts.step_pu) && ~( ...
                                rec.step_range_pu(1) - 1e-9 <= abs(opts.step_pu) && abs(opts.step_pu) <= rec.step_range_pu(2) + 1e-9)
                            prov(end+1) = sprintf("%s: step %g pu outside the identified %g-%g pu - an extrapolation", ...
                                sid, opts.step_pu, rec.step_range_pu(1), rec.step_range_pu(2)); %#ok<AGROW>
                        end
                    end
                end
                if ph == P && ~isempty(study)
                    % A study supersedes the screening: its verdict, its models' provenance.
                    prov = prov(~(contains(prov, "dynamic parameters") | contains(prov, "identification verdict") ...
                        | contains(prov, "extrapolation")));
                    ref = "";
                    if strlength(study.reference) > 0, ref = " (" + study.reference + ")"; end
                    if ~study.passed
                        out(end+1) = "the " + study.tool + " protection study finds this state's protection fails" + ref;
                    elseif ~study.models_identified
                        prov(end+1) = "studied in " + study.tool + ref + " on assumed converter current limits and ride-through";
                    end
                elseif ph == P
                    assumed = st.sources(ismember(st.sources, obj.ride_through_assumed));
                    if ~isempty(assumed)
                        prov(end+1) = "current-limit / ride-through assumed for " + strjoin(assumed, ", ");
                    end
                end
            end
            studied = ph == P && ~isempty(study);
            if sup == mgtwin.Support.PROVISIONAL && isempty(out) && ~studied
                prov(end+1) = note;
            end
            if ~isempty(out)
                verdict = mgtwin.Inside.OUTSIDE; why = out;
            elseif ~isempty(prov)
                verdict = mgtwin.Inside.PROVISIONAL; why = prov;
            else
                verdict = mgtwin.Inside.INSIDE; why = string.empty(1,0);
            end
        end

        % -- lookups -------------------------------------------------------
        function st = stateById(obj, id)
            st = obj.states(string({obj.states.state_id}) == id);
        end
        function r = studyById(obj, id)
            r = mgtwin.ProtectionStudyRecord.empty(1,0);
            if isempty(obj.protection_studies), return; end
            r = obj.protection_studies(string({obj.protection_studies.state_id}) == id);
        end
        function r = identificationFor(obj, sid)
            r = mgtwin.IdentificationRecord.empty(1,0);
            if isempty(obj.identifications), return; end
            r = obj.identifications(string({obj.identifications.source_id}) == sid);
        end

        % -- the artifact --------------------------------------------------
        function s = toStruct(obj)
            ph = struct();
            for k = 1:numel(obj.phenomena)
                ph.(obj.phenomena(k).Value) = struct("support", obj.support(k).Value, "note", obj.notes(k));
            end
            sts = struct();
            for k = 1:numel(obj.states)
                st = obj.states(k);
                ex = struct();
                for p = st.excludedPhenomena(), ex.(p) = st.excludedFor(p); end
                sts.(st.state_id) = struct("grid_connected", st.grid_connected, "sources", {cellstr(st.sources)}, ...
                    "rating_mva", round(st.rating_mva, 4), "sustained_mva", round(st.sustained_mva, 4), "excluded", ex);
            end
            ids = struct();
            for k = 1:numel(obj.identifications)
                r = obj.identifications(k);
                ids.(r.source_id) = struct("verdict", r.verdict, "step_range_pu", r.step_range_pu, "parameters", r.parameters);
            end
            studies = struct();
            for k = 1:numel(obj.protection_studies)
                r = obj.protection_studies(k);
                studies.(r.state_id) = struct("tool", r.tool, "passed", r.passed, ...
                    "models_identified", r.models_identified, "reference", r.reference);
            end
            s = struct("site_id", obj.site_id, "mgtwin_version", obj.version, "phenomena", ph, ...
                "site_wide_fails", {cellstr(obj.site_wide_fails)}, "states", sts, "identifications", ids, ...
                "assumed_sources", {cellstr(obj.assumed_sources)}, "ride_through_assumed", {cellstr(obj.ride_through_assumed)}, ...
                "undeclared", {cellstr(obj.undeclared)}, "protection_studies", studies);
        end

        function txt = toJson(obj, path)
            txt = string(jsonencode(obj.toStruct(), PrettyPrint=true));
            if nargin > 1
                fid = fopen(path, "w", "n", "UTF-8"); fwrite(fid, txt, "char"); fclose(fid);
            end
        end

        function txt = render(obj)
            %RENDER Markdown: the envelope as a reviewer reads it.
            L = ["# Validity envelope: " + obj.site_id, "", "mgtwin " + obj.version, "", "## Phenomena", "", ...
                 "| Phenomenon | Support | Note |", "|---|---|---|"];
            for k = 1:numel(obj.phenomena)
                L(end+1) = "| " + obj.phenomena(k).Value + " | " + obj.support(k).Value + " | " + obj.notes(k) + " |"; %#ok<AGROW>
            end
            if ~isempty(obj.site_wide_fails)
                L = [L, "", "## Site-wide FAILs (everything outside until they clear)", "", "- " + obj.site_wide_fails];
            end
            L = [L, "", "## States", "", "| State | Sources | Rating MVA | Sustained MVA | Outside for |", "|---|---|---|---|---|"];
            for s = obj.states
                ex = strjoin(sort(s.excludedPhenomena()), ", ");
                if strlength(ex) == 0, ex = "-"; end
                if s.grid_connected, rat = "grid"; sus = "grid";
                else, rat = sprintf("%.2f", s.rating_mva); sus = sprintf("%.2f", s.sustained_mva); end
                L(end+1) = sprintf("| %s | %d | %s | %s | %s |", s.state_id, numel(s.sources), rat, sus, ex); %#ok<AGROW>
            end
            L = [L, "", "## Parameters", ""];
            for r = obj.identifications
                L(end+1) = sprintf("- %s: %s, steps %g-%g pu", r.source_id, r.verdict, r.step_range_pu(1), r.step_range_pu(2)); %#ok<AGROW>
            end
            if ~isempty(obj.assumed_sources)
                L(end+1) = "- assumed (no identification): " + strjoin(obj.assumed_sources, ", ");
            end
            if ~isempty(obj.ride_through_assumed)
                L(end+1) = "- current limit / ride-through assumed: " + strjoin(obj.ride_through_assumed, ", ");
            end
            if ~isempty(obj.protection_studies)
                L = [L, "", "## Protection studies", "", "| State | Tool | Verdict | Models | Reference |", "|---|---|---|---|---|"];
                for r = obj.protection_studies
                    if r.passed, v = "passed"; else, v = "FAILS"; end
                    if r.models_identified, m = "identified"; else, m = "assumed"; end
                    L(end+1) = "| " + r.state_id + " | " + r.tool + " | " + v + " | " + m + " | " + r.reference + " |"; %#ok<AGROW>
                end
            end
            if ~isempty(obj.undeclared)
                L = [L, "", "## Undeclared bounds (not invented)", "", "- " + obj.undeclared];
            end
            txt = strjoin(L, newline) + newline;
        end
    end
end
