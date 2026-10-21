classdef Bus
    properties
        id (1,1) string = ""
        v_nom_kv (1,1) double = NaN
        is_poi (1,1) logical = false
    end
    methods
        function obj = Bus(opts)
            arguments
                opts.id (1,1) string
                opts.v_nom_kv (1,1) double {mustBePositive}
                opts.is_poi (1,1) logical = false
            end
            if mgtwin.internal.requireFields(opts, ["id", "v_nom_kv"], "Bus"), return; end
            obj.id = opts.id; obj.v_nom_kv = opts.v_nom_kv; obj.is_poi = opts.is_poi;
        end
    end
end
