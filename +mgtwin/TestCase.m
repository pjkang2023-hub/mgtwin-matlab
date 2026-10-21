classdef TestCase
    %TESTCASE One controller test definition, carried as versioned data.
    %   The Python field `function` is `core_function` here (MATLAB keyword).
    properties
        id (1,1) string = ""
        core_function (1,1) mgtwin.CoreFunction = mgtwin.CoreFunction.DISPATCH
        title (1,1) string = ""
        edition (1,1) string = ""
        clause (1,1) string = ""     % fill from your licensed copy of the standard
        initial_condition (1,1) string = ""
        initiating_event (1,1) string = ""
        measurements (1,:) string = string.empty(1,0)
        criteria (1,:) mgtwin.Criterion = mgtwin.Criterion.empty(1,0)
        requires_island_config (1,1) logical = true
        requires_emt (1,1) logical = false
        notes (1,1) string = ""
    end
    methods
        function obj = TestCase(opts)
            arguments
                opts.id (1,1) string
                opts.core_function (1,1) mgtwin.CoreFunction
                opts.title (1,1) string
                opts.edition (1,1) string
                opts.clause (1,1) string = ""
                opts.initial_condition (1,1) string
                opts.initiating_event (1,1) string
                opts.measurements (1,:) string = string.empty(1,0)
                opts.criteria (1,:) mgtwin.Criterion = mgtwin.Criterion.empty(1,0)
                opts.requires_island_config (1,1) logical = true
                opts.requires_emt (1,1) logical = false
                opts.notes (1,1) string = ""
            end
            if mgtwin.internal.requireFields(opts, ["id", "core_function", "title", "edition", ...
                "initial_condition", "initiating_event"], "TestCase"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
    end
end
