classdef OvercurrentRelay
    %OVERCURRENTRELAY Phase overcurrent element. Pickup is stored in amperes,
    %   deliberately, because that is how it is set in the field and
    %   converting it is where errors enter.
    properties
        id (1,1) string = ""
        switch_id (1,1) string = ""
        ct_ratio (1,1) double = NaN     % e.g. 600.0 for 600:5
        pickup_a (1,1) double = NaN     % primary amperes
        curve (1,1) string = "IEC-VI"
        time_dial (1,1) double = NaN
        directional (1,1) logical = false
        notes (1,1) string = ""
    end
    methods
        function obj = OvercurrentRelay(opts)
            arguments
                opts.id (1,1) string
                opts.switch_id (1,1) string
                opts.ct_ratio (1,1) double {mustBePositive}
                opts.pickup_a (1,1) double {mustBePositive}
                opts.curve (1,1) string = "IEC-VI"
                opts.time_dial (1,1) double {mustBePositive}
                opts.directional (1,1) logical = false
                opts.notes (1,1) string = ""
            end
            if mgtwin.internal.requireFields(opts, ["id", "switch_id", "ct_ratio", "pickup_a", "time_dial"], "OvercurrentRelay"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
    end
end
