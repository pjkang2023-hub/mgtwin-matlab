classdef IngestReport
    %INGESTREPORT Stage 1's reviewable artifact: every tag's result and the
    %   canonical entities the matched tags name.
    %
    %   ENTITIES is a struct array (kind, id, measurements), MEASUREMENTS a
    %   dictionary canonical measurement -> index into RESULTS.
    properties
        results (1,:) mgtwin.TagResult = mgtwin.TagResult.empty(1,0)
        entities = struct("kind", {}, "id", {}, "measurements", {})
    end
    methods
        function obj = IngestReport(results, entities)
            if nargin == 0, return; end
            obj.results = results;
            obj.entities = entities;
        end

        function rs = byStatus(obj, status)
            if isempty(obj.results), rs = obj.results; return; end
            rs = obj.results([obj.results.status] == status);
        end

        function rs = flagged(obj)
            if isempty(obj.results), rs = obj.results; return; end
            rs = obj.results(arrayfun(@(r) r.status ~= mgtwin.TagStatus.MATCHED || ~isempty(r.notes), obj.results));
        end

        function k = entityIndex(obj, kind, id)
            %ENTITYINDEX Index of entity (KIND, ID) in ENTITIES, or [].
            k = [];
            if isempty(obj.entities), return; end
            k = find(string({obj.entities.kind}) == kind & string({obj.entities.id}) == id, 1);
        end

        function r = measurementResult(obj, k, meas)
            %MEASUREMENTRESULT The TagResult of measurement MEAS of entity K, or [].
            r = [];
            m = obj.entities(k).measurements;
            if isKey(m, meas), r = obj.results(m(meas)); end
        end

        function order = sortedEntities(obj)
            order = [];
            if isempty(obj.entities), return; end
            [~, order] = sortrows([string({obj.entities.kind})', string({obj.entities.id})']);
            order = order';
        end

        function s = toStruct(obj)
            counts = struct();
            for st = enumeration("mgtwin.TagStatus")'
                counts.(st.Value) = numel(obj.byStatus(st));
            end
            ents = {};
            for k = obj.sortedEntities()
                e = obj.entities(k);
                ms = struct();
                for m = sort(reshape(keys(e.measurements), 1, []))
                    r = obj.results(e.measurements(m));
                    ms.(m) = struct("tag", r.tag.tag, "unit", r.tag.unit, "scale", r.scale, ...
                        "sample_period_s", r.tag.sample_period_s);
                end
                ents{end+1} = struct("kind", e.kind, "id", e.id, "measurements", ms); %#ok<AGROW>
            end
            fl = {};
            for r = obj.flagged()
                fl{end+1} = struct("tag", r.tag.tag, "status", r.status.Value, "notes", {cellstr(r.notes)}); %#ok<AGROW>
            end
            s = struct("counts", counts, "entities", {ents}, "flagged", {fl});
        end

        function txt = toJson(obj, path)
            txt = string(jsonencode(obj.toStruct(), PrettyPrint=true));
            if nargin > 1
                fid = fopen(path, "w", "n", "UTF-8"); fwrite(fid, txt, "char"); fclose(fid);
            end
        end

        function txt = render(obj)
            c = obj.toStruct().counts;
            parts = string.empty(1,0);
            for f = string(fieldnames(c))', parts(end+1) = f + " " + c.(f); end %#ok<AGROW>
            L = ["# Tag ingest", "", strjoin(parts, ", "), "", "## Entities", "", "| Kind | Id | Measurements |", "|---|---|---|"];
            for k = obj.sortedEntities()
                e = obj.entities(k);
                L(end+1) = "| " + e.kind + " | " + e.id + " | " + strjoin(sort(reshape(keys(e.measurements), 1, [])), ", ") + " |"; %#ok<AGROW>
            end
            fl = obj.flagged();
            if ~isempty(fl)
                L = [L, "", "## Flagged tags", "", "| Tag | Status | Notes |", "|---|---|---|"];
                for r = fl
                    L(end+1) = "| " + r.tag.tag + " | " + r.status.Value + " | " + strjoin(r.notes, "; ") + " |"; %#ok<AGROW>
                end
            end
            txt = strjoin(L, newline) + newline;
        end
    end
end
