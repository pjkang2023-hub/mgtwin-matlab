classdef TagStatus
    %TAGSTATUS How a tag mapped.
    enumeration
        MATCHED ("matched")
        UNMATCHED ("unmatched")
        AMBIGUOUS ("ambiguous")
        DUPLICATE ("duplicate")
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = TagStatus(v)
            obj.Value = v;
        end
    end
end
