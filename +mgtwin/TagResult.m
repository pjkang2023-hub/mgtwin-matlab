classdef TagResult
    %TAGRESULT How one tag mapped: its status, the entity and measurement it
    %   names, the scale to the canonical unit, and the notes a reviewer reads.
    properties
        tag (1,1) mgtwin.Tag = mgtwin.Tag()
        status (1,1) mgtwin.TagStatus = mgtwin.TagStatus.UNMATCHED
        kind (1,1) string = ""
        entity_id (1,1) string = ""
        measurement (1,1) string = ""
        scale double = []
        notes (1,:) string = string.empty(1,0)
    end
    methods
        function obj = TagResult(opts)
            arguments
                opts.tag (1,1) mgtwin.Tag
                opts.status (1,1) mgtwin.TagStatus
                opts.kind (1,1) string = ""
                opts.entity_id (1,1) string = ""
                opts.measurement (1,1) string = ""
                opts.scale double = []
                opts.notes (1,:) string = string.empty(1,0)
            end
            if mgtwin.internal.requireFields(opts, ["tag", "status"], "TagResult"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
    end
end
