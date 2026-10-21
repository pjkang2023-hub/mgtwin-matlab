classdef Base
    %BASE Three-phase per-unit base at one voltage level.
    %
    %   b = mgtwin.Base(s_base_mva=10, v_base_kv=11, f_base_hz=50)
    %
    %   Rationale: most defects in composed power-system models are not wrong
    %   equations. They are (a) a factor of 1000 / sqrt(3), or (b) a flipped
    %   sign convention. Both are mechanically checkable, so they are checked
    %   here rather than left to review. Nothing is stored "in pu" without
    %   also storing the base it is referred to.
    properties (SetAccess = immutable)
        s_base_mva (1,1) double = NaN   % three-phase apparent power base
        v_base_kv  (1,1) double = NaN   % line-to-line RMS voltage base
        f_base_hz  (1,1) double = 50    % nominal frequency
    end
    properties (Dependent)
        z_base_ohm
        i_base_a
    end
    methods
        function obj = Base(opts)
            arguments
                opts.s_base_mva (1,1) double
                opts.v_base_kv  (1,1) double
                opts.f_base_hz  (1,1) double = 50
            end
            if mgtwin.internal.requireFields(opts, ["s_base_mva", "v_base_kv"], "Base"), return; end
            if opts.s_base_mva <= 0
                error("mgtwin:ValueError", "s_base_mva must be positive");
            end
            if opts.v_base_kv <= 0
                error("mgtwin:ValueError", "v_base_kv must be positive");
            end
            if ~ismember(opts.f_base_hz, [50 60])
                error("mgtwin:ValueError", "f_base_hz must be 50 or 60");
            end
            obj.s_base_mva = opts.s_base_mva;
            obj.v_base_kv = opts.v_base_kv;
            obj.f_base_hz = opts.f_base_hz;
        end
        function z = get.z_base_ohm(obj)
            % Z_base = V_LL^2 / S_3ph
            z = obj.v_base_kv^2 / obj.s_base_mva;
        end
        function i = get.i_base_a(obj)
            % I_base = S_3ph / (sqrt(3) * V_LL), in amperes
            i = (obj.s_base_mva * 1e6) / (sqrt(3) * obj.v_base_kv * 1e3);
        end
        function a = amps(obj, i_pu)
            a = i_pu * obj.i_base_a;
        end
        function p = puCurrent(obj, i_amp)
            p = i_amp / obj.i_base_a;
        end
        function o = ohms(obj, z_pu)
            o = z_pu * obj.z_base_ohm;
        end
        function p = puImpedance(obj, z_ohm)
            p = z_ohm / obj.z_base_ohm;
        end
        function z = rebaseImpedance(obj, z_pu, old)
            %REBASEIMPEDANCE Convert a pu impedance from another base to this one.
            z = z_pu * (old.z_base_ohm / obj.z_base_ohm);
        end
    end
end
