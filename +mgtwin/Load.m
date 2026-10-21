classdef Load
    properties
        id (1,1) string = ""
        bus (1,1) string = ""
        p_mw (1,1) double = NaN
        q_mvar (1,1) double = 0
        model (1,1) mgtwin.LoadModel = mgtwin.LoadModel.ZIP
        zip_p (1,3) double = [0 0 1]    % Z, I, P fractions
        zip_q (1,3) double = [0 0 1]
        critical (1,1) logical = false
        sign (1,1) mgtwin.PowerSign = mgtwin.PowerSign.LOAD
    end
    methods
        function obj = Load(opts)
            arguments
                opts.id (1,1) string
                opts.bus (1,1) string
                opts.p_mw (1,1) double
                opts.q_mvar (1,1) double = 0
                opts.model (1,1) mgtwin.LoadModel = mgtwin.LoadModel.ZIP
                opts.zip_p (1,3) double = [0 0 1]
                opts.zip_q (1,3) double = [0 0 1]
                opts.critical (1,1) logical = false
                opts.sign (1,1) mgtwin.PowerSign = mgtwin.PowerSign.LOAD
            end
            if mgtwin.internal.requireFields(opts, ["id", "bus", "p_mw"], "Load"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
            for nm = ["zip_p", "zip_q"]
                if abs(sum(obj.(nm)) - 1.0) > 1e-6
                    error("mgtwin:ValidationError", "ZIP fractions must sum to 1.0, got %g", sum(obj.(nm)));
                end
            end
        end
    end
end
