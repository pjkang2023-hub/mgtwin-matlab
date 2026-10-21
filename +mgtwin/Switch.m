classdef Switch
    %SWITCH Breaker, recloser, or sectionalizer. `is_pcc` marks the utility interface.
    properties
        id (1,1) string = ""
        from_bus (1,1) string = ""
        to_bus (1,1) string = ""
        normally_closed (1,1) logical = true
        is_pcc (1,1) logical = false
    end
    methods
        function obj = Switch(opts)
            arguments
                opts.id (1,1) string
                opts.from_bus (1,1) string
                opts.to_bus (1,1) string
                opts.normally_closed (1,1) logical = true
                opts.is_pcc (1,1) logical = false
            end
            if mgtwin.internal.requireFields(opts, ["id", "from_bus", "to_bus"], "Switch"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
    end
end
