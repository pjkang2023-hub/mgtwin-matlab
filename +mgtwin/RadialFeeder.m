classdef RadialFeeder
    %RADIALFEEDER Unbalanced (phase-frame) power flow for radial feeders,
    %   ladder method: source -> elements{1} -> elements{2} -> ... -> wye PQ
    %   load at the end.
    %
    %   Why this exists despite the "no solvers" rule: the rule is that the
    %   AUTHORING AGENT never writes solvers ad hoc, because its bugs would be
    %   indistinguishable from physics. This is the opposite case: a
    %   deliberate, hand-written library component implementing exactly the
    %   method (Kersting's ladder iterative technique with generalized
    %   transformer matrices) that the IEEE 4-node test feeder was designed
    %   to verify, and it is accepted only against that feeder's published
    %   solutions. Its scope is intentionally narrow: radial networks, full
    %   3x3 phase impedance matrices, grounded-wye constant-PQ loads, and the
    %   two transformer connections the microgrid work needs. Meshed or large
    %   systems belong to OpenDSS, not here.
    %
    %   f = mgtwin.RadialFeeder(v_source_ln=..., elements={...}, load_kw=[..], load_pf=[..])
    properties
        v_source_ln (3,1) double = zeros(3,1)   % complex LN source phasors (or delta-side equivalent LN)
        elements (1,:) cell = {}
        load_kw (1,3) double = [0 0 0]           % per phase
        load_pf (1,3) double = [1 1 1]           % per phase, lagging
    end
    methods
        function obj = RadialFeeder(opts)
            arguments
                opts.v_source_ln (3,1) double
                opts.elements (1,:) cell = {}
                opts.load_kw (1,3) double = [0 0 0]
                opts.load_pf (1,3) double = [1 1 1]
            end
            if mgtwin.internal.requireFields(opts, "v_source_ln", "RadialFeeder"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
        function s = loadSVa(obj)
            s = zeros(3, 1);
            for k = 1:3
                p = obj.load_kw(k) * 1e3;
                phi = acos(obj.load_pf(k));
                s(k) = p * (1.0 + 1i * tan(phi));
            end
        end
        function [v_nodes, i_load] = solve(obj, opts)
            %SOLVE Ladder iterative technique. Returns a cell array of node LN
            %   voltage vectors {V_source, ..., V_load} (numel(elements)+1
            %   entries) and the load current. Fixed tolerance on load-node
            %   voltage magnitude change in volts; refuses to pretend
            %   convergence if max_iter is hit.
            arguments
                obj
                opts.tol_v (1,1) double = 1e-4
                opts.max_iter (1,1) double = 200
            end
            s_load = obj.loadSVa();
            n = numel(obj.elements);
            % initial guess: nominal, propagated through ideal ratios
            v_nodes = cell(1, n + 1);
            v = complex(obj.v_source_ln);
            v_nodes{1} = v;
            for k = 1:n
                v = obj.elements{k}.forward(v, zeros(3, 1));
                v_nodes{k + 1} = v;
            end

            v_load = v_nodes{end};
            dv = NaN;
            for iter = 1:opts.max_iter %#ok<NASGU>
                i_load = conj(s_load ./ v_load);
                % backward sweep: accumulate to the source
                v_bk = v_load;
                currents = cell(1, n + 1);
                currents{n + 1} = i_load;
                for k = n:-1:1
                    [v_bk, i_bk] = obj.elements{k}.backward(v_bk, currents{k + 1});
                    currents{k} = i_bk;
                end
                % forward sweep from the true source voltage
                v_nodes{1} = complex(obj.v_source_ln);
                for k = 1:n
                    v_nodes{k + 1} = obj.elements{k}.forward(v_nodes{k}, currents{k + 1});
                end
                dv = max(abs(abs(v_nodes{end}) - abs(v_load)));
                v_load = v_nodes{end};
                if dv < opts.tol_v
                    return;
                end
            end
            error("mgtwin:ConvergenceError", ...
                "ladder sweep did not converge in %d iterations (last dV = %.3e V); " + ...
                "refusing to return an unconverged answer", opts.max_iter, dv);
        end
    end
end
