classdef TransformerGYGY
    %TRANSFORMERGYGY Grounded-wye / grounded-wye step-down, per Kersting.
    %
    %   a = nt*I, b = nt*Zt, c = 0, d = I/nt, A = I/nt, B = Zt,
    %   with nt the LN (== LL) voltage ratio and Zt the per-phase series
    %   impedance in ohms referred to the LOW side.
    %
    %   tx = mgtwin.TransformerGYGY(kvll_hi=12.47, kvll_lo=4.16, s_mva=6, r_pct=1, x_pct=6)
    properties
        kvll_hi (1,1) double = NaN
        kvll_lo (1,1) double = NaN
        s_mva (1,1) double = NaN
        r_pct (1,1) double = 0
        x_pct (1,1) double = 0
        nt (1,1) double = NaN
        zt (1,1) double = 0
        a (3,3) double = zeros(3)
        b (3,3) double = zeros(3)
        d (3,3) double = zeros(3)
        A (3,3) double = zeros(3)
        B (3,3) double = zeros(3)
    end
    methods
        function obj = TransformerGYGY(opts)
            arguments
                opts.kvll_hi (1,1) double
                opts.kvll_lo (1,1) double
                opts.s_mva (1,1) double
                opts.r_pct (1,1) double
                opts.x_pct (1,1) double
            end
            if mgtwin.internal.requireFields(opts, ["kvll_hi", "kvll_lo", "s_mva", "r_pct", "x_pct"], "TransformerGYGY"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
            obj.nt = obj.kvll_hi / obj.kvll_lo;
            z_base_lo = obj.kvll_lo^2 / obj.s_mva;
            obj.zt = complex(obj.r_pct, obj.x_pct) / 100.0 * z_base_lo;
            I = eye(3);
            obj.a = obj.nt * I;
            obj.b = obj.nt * obj.zt * I;
            obj.d = I / obj.nt;
            obj.A = I / obj.nt;
            obj.B = obj.zt * I;
        end
        function [v_up, i_up] = backward(obj, v_dn, i_dn)
            v_up = obj.a * v_dn + obj.b * i_dn;
            i_up = obj.d * i_dn;
        end
        function v_dn = forward(obj, v_up, i_dn)
            v_dn = obj.A * v_up - obj.B * i_dn;
        end
        function tf = passesZeroSequence(~)
            tf = true;
        end
    end
end
