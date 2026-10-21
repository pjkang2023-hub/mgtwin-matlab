classdef Criterion
    %CRITERION One pass/fail measurement.
    %
    %   `limit` is intentionally optional ([] = none): many limits are
    %   project-specific or come from the interconnection agreement rather
    %   than the standard, and inventing a number would be worse than leaving
    %   it to be filled in.
    properties
        metric (1,1) string = ""
        unit (1,1) string = ""
        comparator (1,1) string = "<="     % <=, >=, <, >, within
        limit double = []
        limit_source (1,1) string = "project"   % standard | interconnection_agreement | project
        notes (1,1) string = ""
    end
    methods
        function obj = Criterion(opts)
            arguments
                opts.metric (1,1) string
                opts.unit (1,1) string
                opts.comparator (1,1) string
                opts.limit double = []
                opts.limit_source (1,1) string = "project"
                opts.notes (1,1) string = ""
            end
            if mgtwin.internal.requireFields(opts, ["metric", "unit", "comparator"], "Criterion"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
            if ~ismember(obj.comparator, ["<=", ">=", "<", ">", "within"])
                error("mgtwin:ValidationError", "comparator must be one of <=, >=, <, >, within; got '%s'", obj.comparator);
            end
        end
    end
end
