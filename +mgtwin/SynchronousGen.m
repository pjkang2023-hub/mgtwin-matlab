classdef SynchronousGen
    %SYNCHRONOUSGEN Diesel/gas genset or turbine. Contributes real short-circuit current.
    properties
        id (1,1) string = ""
        bus (1,1) string = ""
        s_rated_mva (1,1) double = NaN
        h_sec (1,1) double = NaN
        xd_subtransient_pu (1,1) double = NaN
        droop_pu (1,1) double = 0.04
        isochronous_capable (1,1) logical = true
        neutral_grounded (1,1) logical = false
    end
    methods
        function obj = SynchronousGen(opts)
            arguments
                opts.id (1,1) string
                opts.bus (1,1) string
                opts.s_rated_mva (1,1) double {mustBePositive}
                opts.h_sec (1,1) double {mustBePositive}
                opts.xd_subtransient_pu (1,1) double {mustBePositive}
                opts.droop_pu (1,1) double {mustBePositive} = 0.04
                opts.isochronous_capable (1,1) logical = true
                opts.neutral_grounded (1,1) logical = false
            end
            if mgtwin.internal.requireFields(opts, ["id", "bus", "s_rated_mva", "h_sec", "xd_subtransient_pu"], "SynchronousGen"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
            if obj.xd_subtransient_pu > 1.0
                error("mgtwin:ValidationError", "xd_subtransient_pu must be <= 1.0 (pu on own rating)");
            end
        end
        function i = faultContributionA(obj, base)
            %FAULTCONTRIBUTIONA I_f ~= 1.0 / X''_d, on own rating.
            i_rated_a = (obj.s_rated_mva * 1e6) / (sqrt(3) * base.v_base_kv * 1e3);
            i = i_rated_a / obj.xd_subtransient_pu;
        end
    end
end
