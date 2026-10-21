classdef StateEnvelope
    %STATEENVELOPE One state's part of the validity envelope: its energised
    %   sources, their rating (all, and less storage), and the phenomena its
    %   gate FAILs exclude it from.
    properties
        state_id (1,1) string = ""
        grid_connected (1,1) logical = false
        sources (1,:) string = string.empty(1,0)
        rating_mva (1,1) double = 0       % every energised source
        sustained_mva (1,1) double = 0    % less storage
        excluded = dictionary(string.empty, cell.empty)   % phenomenon value -> {string array of gate findings}
    end
    methods
        function obj = StateEnvelope(opts)
            arguments
                opts.state_id (1,1) string
                opts.grid_connected (1,1) logical = false
                opts.sources (1,:) string = string.empty(1,0)
                opts.rating_mva (1,1) double = 0
                opts.sustained_mva (1,1) double = 0
                opts.excluded = dictionary(string.empty, cell.empty)
            end
            if mgtwin.internal.requireFields(opts, "state_id", "StateEnvelope"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
        function x = excludedFor(obj, ph)
            %EXCLUDEDFOR The gate findings that exclude this state from phenomenon value PH.
            x = string.empty(1,0);
            if isConfigured(obj.excluded) && isKey(obj.excluded, ph), x = obj.excluded{ph}; end
        end
        function k = excludedPhenomena(obj)
            k = string.empty(1,0);
            if isConfigured(obj.excluded), k = reshape(keys(obj.excluded), 1, []); end
        end
    end
end
