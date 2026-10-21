classdef SLGResult
    %SLGRESULT Single-line-to-ground fault result, per unit on a common base.
    properties
        i_fault_pu (1,1) double = 0          % phase-a fault current (complex)
        v_abc_pu (1,3) double = [0 0 0]      % phase voltages at the fault bus (complex)
        v_max_unfaulted_pu (1,1) double = NaN % the number the insulation cares about
        grounded (1,1) logical = false
    end
    methods
        function obj = SLGResult(i_fault_pu, v_abc_pu, v_max_unfaulted_pu, grounded)
            if nargin == 0, return; end
            obj.i_fault_pu = i_fault_pu;
            obj.v_abc_pu = v_abc_pu;
            obj.v_max_unfaulted_pu = v_max_unfaulted_pu;
            obj.grounded = grounded;
        end
        function s = render(obj, opts)
            arguments
                obj
                opts.i_base_a double = []
                opts.v_base_ln double = []
            end
            mags = abs(obj.v_abc_pu);
            if obj.grounded
                cur = sprintf("%.3f pu", abs(obj.i_fault_pu));
                if ~isempty(opts.i_base_a)
                    cur = cur + sprintf(" = %s A", mgtwin.internal.fmtThousands(abs(obj.i_fault_pu) * opts.i_base_a));
                end
            else
                cur = "~0 (capacitive charging only -- below any overcurrent element)";
            end
            ph = 'abc';
            parts = strings(1, 3);
            for k = 1:3
                parts(k) = sprintf("%s=%.3f pu", ph(k), mags(k));
            end
            mx = sprintf("%.3f pu", obj.v_max_unfaulted_pu);
            if ~isempty(opts.v_base_ln)
                mx = mx + sprintf(" = %.2f kV LN", obj.v_max_unfaulted_pu * opts.v_base_ln / 1e3);
            end
            lines = ["  fault current  : " + cur, ...
                     "  phase voltages : " + strjoin(parts, "  "), ...
                     "  max unfaulted  : " + mx];
            s = strjoin(lines, newline);
        end
    end
end
