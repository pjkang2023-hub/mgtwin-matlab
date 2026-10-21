function v = balancedSourceLn(kvll, angle_a_deg)
%BALANCEDSOURCELN Balanced three-phase LN source phasors (3x1, complex, volts).
arguments
    kvll (1,1) double
    angle_a_deg (1,1) double = 0.0
end
vln = kvll * 1e3 / sqrt(3);
th = deg2rad(angle_a_deg);
v = vln * [exp(1i * th); exp(1i * (th - 2 * pi / 3)); exp(1i * (th + 2 * pi / 3))];
end
