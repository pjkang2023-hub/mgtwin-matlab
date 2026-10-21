classdef Tag
    %TAG One point of a SCADA or historian tag list.
    properties
        tag (1,1) string = ""
        unit (1,1) string = ""
        description (1,1) string = ""
        sample_period_s double = []    % [] = unknown
    end
    methods
        function obj = Tag(opts)
            arguments
                opts.tag (1,1) string
                opts.unit (1,1) string = ""
                opts.description (1,1) string = ""
                opts.sample_period_s double {mustBeScalarOrEmpty} = []
            end
            if mgtwin.internal.requireFields(opts, "tag", "Tag"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
    end
end
