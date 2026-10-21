classdef IdentificationResult
    %IDENTIFICATIONRESULT Least-squares estimate plus an honest confidence report.
    properties
        names (1,:) string = string.empty(1,0)
        theta (1,:) double = []
        std_err (1,:) double = []
        rel_se (1,:) double = []
        cond_number (1,1) double = NaN
        weak_direction struct = struct()   % name -> component of least-determined direction
        sigma_hat (1,1) double = NaN
        rmse (1,1) double = NaN
        whiteness (1,1) mgtwin.WhitenessResult = mgtwin.WhitenessResult()
        verdict (1,1) mgtwin.Verdict = mgtwin.Verdict.NOT_IDENTIFIABLE
        notes (1,:) string = string.empty(1,0)
    end
    methods
        function th = thetaStruct(obj)
            %THETASTRUCT Estimates as a struct keyed by parameter name.
            th = struct();
            for k = 1:numel(obj.names)
                th.(obj.names(k)) = obj.theta(k);
            end
        end
        function s = render(obj)
            REL_SE_LIMIT = mgtwin.identifyConstants().REL_SE_LIMIT;
            lines = "verdict: " + upper(obj.verdict.Value);
            lines(end+1) = sprintf("  %-12s%12s%12s%10s", "parameter", "estimate", "std err", "rel se");
            for k = 1:numel(obj.names)
                flag = "";
                if obj.rel_se(k) > REL_SE_LIMIT, flag = "  <-- weak"; end
                lines(end+1) = sprintf("  %-12s%12.5g%12.3g%8.1f%%%s", ...
                    obj.names(k), obj.theta(k), obj.std_err(k), 100 * obj.rel_se(k), flag); %#ok<AGROW>
            end
            lines(end+1) = sprintf("  rmse = %.3e   sigma_hat = %.3e", obj.rmse, obj.sigma_hat);
            lines(end+1) = sprintf("  cond(scaled sensitivity) = %.3e", obj.cond_number);
            wd = fieldnames(obj.weak_direction);
            if ~isempty(wd)
                parts = strings(1, numel(wd));
                for k = 1:numel(wd)
                    parts(k) = sprintf("%s:%+.2f", wd{k}, obj.weak_direction.(wd{k}));
                end
                lines(end+1) = "  least-determined direction: " + strjoin(parts, "  ");
            end
            lines(end+1) = "  " + obj.whiteness.render();
            for k = 1:numel(obj.notes)
                lines(end+1) = "  note: " + obj.notes(k); %#ok<AGROW>
            end
            s = strjoin(lines, newline);
        end
    end
end
