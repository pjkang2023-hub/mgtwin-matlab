classdef Branch
    properties
        id (1,1) string = ""
        from_bus (1,1) string = ""
        to_bus (1,1) string = ""
        r_pu (1,1) double = 0
        x_pu (1,1) double = NaN
        b_pu (1,1) double = 0
        s_base_mva (1,1) double = NaN   % base the pu impedance refers to
        v_base_kv (1,1) double = NaN    % base the pu impedance refers to
        rating_mva (1,1) double = NaN
    end
    methods
        function obj = Branch(opts)
            arguments
                opts.id (1,1) string
                opts.from_bus (1,1) string
                opts.to_bus (1,1) string
                opts.r_pu (1,1) double {mustBeNonnegative}
                opts.x_pu (1,1) double {mustBePositive}
                opts.b_pu (1,1) double = 0
                opts.s_base_mva (1,1) double {mustBePositive}
                opts.v_base_kv (1,1) double {mustBePositive}
                opts.rating_mva (1,1) double {mustBePositive}
            end
            if mgtwin.internal.requireFields(opts, ["id", "from_bus", "to_bus", "r_pu", "x_pu", ...
                "s_base_mva", "v_base_kv", "rating_mva"], "Branch"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
    end
end
