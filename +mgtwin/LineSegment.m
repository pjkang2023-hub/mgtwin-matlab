classdef LineSegment
    %LINESEGMENT Series 3x3 phase-impedance element: z_ohm_per_mile * length.
    %
    %   Ladder interface (Kersting):
    %     backward: [V_up] = [V_dn] + [Z][I_dn],  [I_up] = [I_dn]
    %     forward:  [V_dn] = [V_up] - [Z][I_dn]
    properties
        z_ohm_per_mile (3,3) double = zeros(3)   % complex
        length_ft (1,1) double = 0
        Z (3,3) double = zeros(3)                % total series impedance, ohms
    end
    methods
        function obj = LineSegment(z_ohm_per_mile, length_ft)
            if nargin == 0, return; end
            if ~isequal(size(z_ohm_per_mile), [3 3])
                error("mgtwin:ValueError", "phase impedance matrix must be 3x3");
            end
            obj.z_ohm_per_mile = z_ohm_per_mile;
            obj.length_ft = length_ft;
            obj.Z = z_ohm_per_mile * (length_ft / 5280.0);
        end
        function [v_up, i_up] = backward(obj, v_dn, i_dn)
            v_up = v_dn + obj.Z * i_dn;
            i_up = i_dn;
        end
        function v_dn = forward(obj, v_up, i_dn)
            v_dn = v_up - obj.Z * i_dn;
        end
    end
end
