classdef Converter
    %CONVERTER Inverter-based resource: PV, BESS, wind, or a hybrid plant.
    properties
        id (1,1) string = ""
        bus (1,1) string = ""
        s_rated_mva (1,1) double = NaN
        control (1,1) mgtwin.ConverterControl = mgtwin.ConverterControl.GFL
        params (1,1) mgtwin.ConverterParams = mgtwin.ConverterParams()
        sign (1,1) mgtwin.PowerSign = mgtwin.PowerSign.GENERATOR
        vendor (1,1) string = ""
        firmware (1,1) string = ""   % ride-through behaviour is firmware-bound
        energy_mwh double = []       % BESS only
    end
    methods
        function obj = Converter(opts)
            arguments
                opts.id (1,1) string
                opts.bus (1,1) string
                opts.s_rated_mva (1,1) double {mustBePositive}
                opts.control (1,1) mgtwin.ConverterControl
                opts.params (1,1) mgtwin.ConverterParams
                opts.sign (1,1) mgtwin.PowerSign = mgtwin.PowerSign.GENERATOR
                opts.vendor (1,1) string = ""
                opts.firmware (1,1) string = ""
                opts.energy_mwh double = []
            end
            if mgtwin.internal.requireFields(opts, ["id", "bus", "s_rated_mva", "control", "params"], "Converter"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
            if ~isempty(obj.energy_mwh) && obj.energy_mwh <= 0
                error("mgtwin:ValidationError", "energy_mwh must be positive");
            end
            if obj.control.isGridForming() && isempty(obj.params.p_f_droop_pu)
                error("mgtwin:ValidationError", ...
                    "converter '%s' declares grid-forming control but no P-f droop gain", obj.id);
            end
            if obj.control == mgtwin.ConverterControl.GFM_VSM && isempty(obj.params.h_sec)
                error("mgtwin:ValidationError", ...
                    "converter '%s' declares VSM control but no inertia constant", obj.id);
            end
        end
        function i = faultContributionA(obj, base)
            %FAULTCONTRIBUTIONA Symmetrical fault current contribution in
            %   amperes, islanded. A converter is a current-limited source, not
            %   a voltage source behind subtransient reactance: contribution is
            %   its own rated current times its transient limit -- typically
            %   1.1-1.5 pu, not the 5-10 pu a synchronous machine would deliver.
            i_rated_a = (obj.s_rated_mva * 1e6) / (sqrt(3) * base.v_base_kv * 1e3);
            i = i_rated_a * obj.params.i_limit_transient_pu;
        end
    end
end
