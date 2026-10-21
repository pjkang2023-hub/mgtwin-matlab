classdef ConverterParams
    %CONVERTERPARAMS Parameter vector for a converter's RMS-timescale representation.
    %
    %   Known gap, carried explicitly: the WECC generic GFM specification for
    %   REGFM_A1 states that steady-state current limiting and advanced voltage
    %   ride-through are NOT included. Those two behaviours are exactly what
    %   sets islanded fault current, so they are represented here as separate
    %   fields that must be either identified from response data or declared
    %   unknown. `ride_through_identified` is the honesty flag: false means any
    %   protection conclusion drawn from this model is provisional.
    %
    %   Optional fields use [] for "not declared" (Python None).
    properties
        p_f_droop_pu double = []        % P-f droop, pu on own rating (GFM only)
        q_v_droop_pu double = []
        h_sec double = []               % virtual inertia constant
        tp_sec (1,1) double = 0.05      % power measurement filter
        tv_sec (1,1) double = 0.02      % voltage measurement filter
        i_limit_transient_pu (1,1) double = 1.2   % transient current limit, pu on own rating
        i_limit_steady_pu double = []   % steady-state limit; [] = not identified
        ride_through_identified (1,1) logical = false
    end
    methods
        function obj = ConverterParams(opts)
            arguments
                opts.p_f_droop_pu double = []
                opts.q_v_droop_pu double = []
                opts.h_sec double = []
                opts.tp_sec (1,1) double {mustBePositive} = 0.05
                opts.tv_sec (1,1) double {mustBePositive} = 0.02
                opts.i_limit_transient_pu (1,1) double {mustBePositive} = 1.2
                opts.i_limit_steady_pu double = []
                opts.ride_through_identified (1,1) logical = false
            end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
            if ~isempty(obj.p_f_droop_pu) && obj.p_f_droop_pu <= 0
                error("mgtwin:ValidationError", "p_f_droop_pu must be positive");
            end
            if ~isempty(obj.q_v_droop_pu) && obj.q_v_droop_pu <= 0
                error("mgtwin:ValidationError", "q_v_droop_pu must be positive");
            end
            if ~isempty(obj.h_sec) && obj.h_sec < 0
                error("mgtwin:ValidationError", "h_sec must be non-negative");
            end
            if ~isempty(obj.i_limit_steady_pu)
                if obj.i_limit_steady_pu <= 0
                    error("mgtwin:ValidationError", "i_limit_steady_pu must be positive");
                end
                if obj.i_limit_steady_pu > obj.i_limit_transient_pu
                    error("mgtwin:ValidationError", ...
                        "steady-state current limit exceeds transient limit; check which is which");
                end
            end
        end
    end
end
