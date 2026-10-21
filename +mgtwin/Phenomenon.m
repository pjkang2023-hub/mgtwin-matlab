classdef Phenomenon
    %PHENOMENON What a result is about: the phenomena the envelope speaks to.
    enumeration
        LOADING ("loading")
        FREQUENCY ("frequency")
        PROTECTION ("protection")
        GROUNDING ("grounding")
        ENERGISATION ("energisation")
        VOLTAGE ("voltage")
        EMT ("emt")
        DISPATCH ("dispatch")
        RECONNECTION ("reconnection")
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = Phenomenon(v)
            obj.Value = v;
        end
    end
end
