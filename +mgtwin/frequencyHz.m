function f = frequencyHz(omega_pu, f_nom)
%FREQUENCYHZ Convert per-unit speed to Hz.
arguments
    omega_pu double
    f_nom (1,1) double = 50.0
end
f = omega_pu * f_nom;
end
