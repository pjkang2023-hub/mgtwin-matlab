classdef EvalReport < handle
    %EVALREPORT Scores the identifier's REFUSAL BEHAVIOUR, not its parameter
    %   recovery. Each run lands in one cell:
    %
    %                             | bias < 5%        | bias >= 5%
    %       verdict = IDENTIFIED  | TRUE CONFIDENCE  | FALSE CONFIDENCE  <- forbidden
    %       verdict refuses       | OVER-REFUSAL     | TRUE REFUSAL
    properties
        runs (1,:) mgtwin.EvalRun = mgtwin.EvalRun.empty(1,0)
    end
    methods
        function add(obj, r)
            obj.runs(end+1) = r;
        end
        function c = cellCounts(obj)
            c = struct("true_confidence", 0, "false_confidence", 0, ...
                       "true_refusal", 0, "over_refusal", 0);
            for k = 1:numel(obj.runs)
                c.(obj.runs(k).cell) = c.(obj.runs(k).cell) + 1;
            end
        end
        function r = falseConfidenceRate(obj)
            c = obj.cellCounts();
            n = c.true_confidence + c.false_confidence + c.true_refusal + c.over_refusal;
            if n == 0, r = 0.0; else, r = c.false_confidence / n; end
        end
        function [names, groups] = byScenario(obj)
            names = string.empty(1,0);
            groups = {};
            for k = 1:numel(obj.runs)
                nm = obj.runs(k).scenario;
                j = find(names == nm, 1);
                if isempty(j)
                    names(end+1) = nm; %#ok<AGROW>
                    groups{end+1} = obj.runs(k); %#ok<AGROW>
                else
                    groups{j}(end+1) = obj.runs(k);
                end
            end
        end
        function s = render(obj)
            lines = sprintf("%-20s%-10s%6s%9s%10s   verdict distribution", ...
                "scenario", "truth", "seeds", "refused", "max bias");
            [names, groups] = obj.byScenario();
            for k = 1:numel(names)
                runs = groups{k};
                refused = sum(arrayfun(@(r) r.verdict.isRefusal(), runs));
                worst = max(arrayfun(@(r) r.maxBias(), runs));
                vals = arrayfun(@(r) r.verdict.Value, runs);
                [u, ~, ic] = unique(vals);
                parts = strings(1, numel(u));
                for j = 1:numel(u)
                    parts(j) = sprintf("%s:%d", u(j), sum(ic == j));
                end
                if runs(1).mismatch, truth = "MISMATCH"; else, truth = "nominal"; end
                lines(end+1) = sprintf("%-20s%-10s%6d%9d%8.1f%%   %s", ...
                    names(k), truth, numel(runs), refused, 100 * worst, strjoin(parts, ", ")); %#ok<AGROW>
            end
            c = obj.cellCounts();
            n = c.true_confidence + c.false_confidence + c.true_refusal + c.over_refusal;
            lines(end+1) = "";
            lines(end+1) = "confusion (verdict vs consequence):";
            lines(end+1) = sprintf("%24s%14s%14s", "", "bias < 5%", "bias >= 5%");
            lines(end+1) = sprintf("%-24s%14d%14d   <- forbidden cell", "  IDENTIFIED", c.true_confidence, c.false_confidence);
            lines(end+1) = sprintf("%-24s%14d%14d", "  refused", c.over_refusal, c.true_refusal);
            lines(end+1) = "";
            if n == 0, orr = 0; else, orr = c.over_refusal / n; end
            lines(end+1) = sprintf("false-confidence rate: %d/%d = %.1f%%    over-refusal rate: %d/%d = %.1f%%", ...
                c.false_confidence, n, 100 * obj.falseConfidenceRate(), c.over_refusal, n, 100 * orr);
            s = strjoin(lines, newline);
        end
    end
end
