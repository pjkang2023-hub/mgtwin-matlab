classdef TransformerDGY
    %TRANSFORMERDGY Delta (high) / grounded-wye (low), step-down, American
    %   standard (high side leads low by 30 degrees), per Kersting:
    %
    %     nt  = kVLL_hi / kVLN_lo
    %     a   = -(nt/3) * [[0,2,1],[1,0,2],[2,1,0]]
    %     b   = a * Zt
    %     d   = (1/nt) * [[1,-1,0],[0,1,-1],[-1,0,1]]
    %     A   = (1/nt) * [[1,0,-1],[-1,1,0],[0,-1,1]]
    %     B   = Zt * I
    %
    %   Zt in ohms per phase referred to the low (wye) side. The delta winding
    %   provides no zero-sequence path toward the high side; the grounded-wye
    %   low winding is a zero-sequence source for its own zone -- the algebra
    %   here is the power-flow face of the same fact the grounding gate checks
    %   structurally.
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
        function obj = TransformerDGY(opts)
            arguments
                opts.kvll_hi (1,1) double
                opts.kvll_lo (1,1) double
                opts.s_mva (1,1) double
                opts.r_pct (1,1) double
                opts.x_pct (1,1) double
            end
            if mgtwin.internal.requireFields(opts, ["kvll_hi", "kvll_lo", "s_mva", "r_pct", "x_pct"], "TransformerDGY"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
            kvln_lo = obj.kvll_lo / sqrt(3);
            obj.nt = obj.kvll_hi / kvln_lo;
            z_base_lo = obj.kvll_lo^2 / obj.s_mva;
            obj.zt = complex(obj.r_pct, obj.x_pct) / 100.0 * z_base_lo;
            perm = [0 2 1; 1 0 2; 2 1 0];
            obj.a = -(obj.nt / 3.0) * perm;
            obj.b = obj.a * obj.zt;
            obj.d = (1.0 / obj.nt) * [1 -1 0; 0 1 -1; -1 0 1];
            obj.A = (1.0 / obj.nt) * [1 0 -1; -1 1 0; 0 -1 1];
            obj.B = obj.zt * eye(3);
        end
        function [v_up, i_up] = backward(obj, v_dn, i_dn)
            v_up = obj.a * v_dn + obj.b * i_dn;
            i_up = obj.d * i_dn;
        end
        function v_dn = forward(obj, v_up, i_dn)
            v_dn = obj.A * v_up - obj.B * i_dn;
        end
        function tf = passesZeroSequence(~)
            tf = false;
        end
    end
end
