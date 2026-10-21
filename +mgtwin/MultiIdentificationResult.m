classdef MultiIdentificationResult
    %MULTIIDENTIFICATIONRESULT Result of the amplitude-consistency protocol.
    properties
        results (1,:) mgtwin.IdentificationResult = mgtwin.IdentificationResult.empty(1,0)
        names (1,:) string = string.empty(1,0)
        theta_pooled double = []          % [] when refused
        spread_rel struct = struct()      % name -> relative cross-experiment spread
        verdict (1,1) mgtwin.Verdict = mgtwin.Verdict.NOT_IDENTIFIABLE
        notes (1,:) string = string.empty(1,0)
    end
    methods
        function s = render(obj)
            lines = "multi-experiment verdict: " + upper(obj.verdict.Value);
            for k = 1:numel(obj.results)
                r = obj.results(k);
                est = strings(1, numel(r.names));
                for j = 1:numel(r.names)
                    est(j) = sprintf("%s=%.4g", r.names(j), r.theta(j));
                end
                lines(end+1) = sprintf("  exp %d: %-20s %s", k, r.verdict.Value, strjoin(est, ", ")); %#ok<AGROW>
            end
            sf = fieldnames(obj.spread_rel);
            if ~isempty(sf)
                parts = strings(1, numel(sf));
                for j = 1:numel(sf)
                    parts(j) = sprintf("%s:%.1f%%", sf{j}, 100 * obj.spread_rel.(sf{j}));
                end
                lines(end+1) = "  cross-experiment spread: " + strjoin(parts, "  ");
            end
            if ~isempty(obj.theta_pooled)
                parts = strings(1, numel(obj.names));
                for j = 1:numel(obj.names)
                    parts(j) = sprintf("%s=%.4g", obj.names(j), obj.theta_pooled(j));
                end
                lines(end+1) = "  pooled: " + strjoin(parts, ", ");
            end
            for k = 1:numel(obj.notes)
                lines(end+1) = "  note: " + obj.notes(k); %#ok<AGROW>
            end
            s = strjoin(lines, newline);
        end
    end
end
