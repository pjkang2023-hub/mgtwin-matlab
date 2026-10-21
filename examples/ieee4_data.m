function D = ieee4_data()
%IEEE4_DATA IEEE 4-node test feeder data and published solutions.
%   Shared by examples/ieee4_rung2.m and tests/MgtwinTest.m.

% 4-wire grounded-wye phase impedance matrix, ohms/mile (IEEE 4-node doc).
D.Z_Y = [ ...
    0.4576 + 1.0780i, 0.1559 + 0.5017i, 0.1535 + 0.3849i; ...
    0.1559 + 0.5017i, 0.4666 + 1.0482i, 0.1580 + 0.4236i; ...
    0.1535 + 0.3849i, 0.1580 + 0.4236i, 0.4615 + 1.0651i];

D.LOAD_KW = [1275.0, 1800.0, 2375.0];
D.LOAD_PF = [0.85, 0.90, 0.95];

% Published IEEE solutions, unbalanced step-down (LN volts / degrees).
% Rows are phases a, b, c; columns [magnitude_V, angle_deg].
D.REFS.GrY_GrY.v3 = [2305, -2.3; 2255, -123.6; 2203, 114.8];
D.REFS.GrY_GrY.v4 = [2175, -4.1; 1930, -126.8; 1833, 102.8];
D.REFS.D_GrY.v3   = [2290, -32.4; 2261, -153.8; 2214, 85.2];
D.REFS.D_GrY.v4   = [2157, -34.2; 1936, -157.0; 1849, 73.4];

% Published rounding is 1 V / 0.1 deg; allow 2 V and 0.15 deg.
D.TOL_V = 2.0;
D.TOL_DEG = 0.15;
end
