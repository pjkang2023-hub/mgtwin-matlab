classdef PlantParams
    %PLANTPARAMS Truth-plant parameters for identification evals.
    %
    %   The library form (simulateGfm) is what the identifier fits. Each
    %   mechanism below is something real gensets and BESS actually have and
    %   datasheets don't mention; [] means absent.
    %
    %     ramp_limit_pu_s  BESS power ramp limiter
    %     deadband_hz      governor frequency deadband: no droop response inside +/-db
    %     p_max_pu         output power clamp
    %     extra_lag_sec    second lag in the power path (actuator / turbine)
    %     knee             [band_hz, rp_outside]: piecewise droop (FFR-style)
    properties
        rp_pu (1,1) double = 0.05
        tp_sec (1,1) double = 0.20
        h_sec (1,1) double = 2.0
        p_ref (1,1) double = 0.0
        ramp_limit_pu_s double = []
        deadband_hz double = []
        p_max_pu double = []
        extra_lag_sec double = []
        knee double = []
        f_nom (1,1) double = 60.0
    end
    methods
        function obj = PlantParams(opts)
            arguments
                opts.rp_pu (1,1) double = 0.05
                opts.tp_sec (1,1) double = 0.20
                opts.h_sec (1,1) double = 2.0
                opts.p_ref (1,1) double = 0.0
                opts.ramp_limit_pu_s double = []
                opts.deadband_hz double = []
                opts.p_max_pu double = []
                opts.extra_lag_sec double = []
                opts.knee double = []
                opts.f_nom (1,1) double = 60.0
            end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
    end
end
