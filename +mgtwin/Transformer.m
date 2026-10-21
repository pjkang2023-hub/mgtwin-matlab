classdef Transformer
    properties
        id (1,1) string = ""
        hv_bus (1,1) string = ""
        lv_bus (1,1) string = ""
        s_rated_mva (1,1) double = NaN
        hv_kv (1,1) double = NaN
        lv_kv (1,1) double = NaN
        x_pu (1,1) double = NaN     % on own rating
        r_pu (1,1) double = 0       % on own rating
        hv_config (1,1) mgtwin.WindingConfig = mgtwin.WindingConfig.DELTA
        lv_config (1,1) mgtwin.WindingConfig = mgtwin.WindingConfig.DELTA
        % Peak magnetising inrush as a multiple of rated rms current on first
        % energisation (typ. 8-12 for distribution units). Default is ASSUMED;
        % set inrush_identified once taken from a test or the nameplate.
        inrush_pu (1,1) double = 10.0
        inrush_identified (1,1) logical = false
    end
    methods
        function obj = Transformer(opts)
            arguments
                opts.id (1,1) string
                opts.hv_bus (1,1) string
                opts.lv_bus (1,1) string
                opts.s_rated_mva (1,1) double {mustBePositive}
                opts.hv_kv (1,1) double {mustBePositive}
                opts.lv_kv (1,1) double {mustBePositive}
                opts.x_pu (1,1) double {mustBePositive}
                opts.r_pu (1,1) double {mustBeNonnegative} = 0
                opts.hv_config (1,1) mgtwin.WindingConfig
                opts.lv_config (1,1) mgtwin.WindingConfig
                opts.inrush_pu (1,1) double {mustBePositive} = 10.0
                opts.inrush_identified (1,1) logical = false
            end
            if mgtwin.internal.requireFields(opts, ["id", "hv_bus", "lv_bus", "s_rated_mva", ...
                "hv_kv", "lv_kv", "x_pu", "hv_config", "lv_config"], "Transformer"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
        function tf = providesZeroSequencePathTo(obj, side)
            %PROVIDESZEROSEQUENCEPATHTO A grounded-wye winding provides a
            %   zero-sequence path to its own side. SIDE is "hv" or "lv".
            if string(side) == "hv"
                cfg = obj.hv_config;
            else
                cfg = obj.lv_config;
            end
            tf = cfg == mgtwin.WindingConfig.WYE_GROUNDED;
        end
    end
end
