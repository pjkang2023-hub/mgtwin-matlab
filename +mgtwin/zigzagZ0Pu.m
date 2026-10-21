function z = zigzagZ0Pu(z0_ohm_per_phase, v_kv_ll, s_base_mva)
%ZIGZAGZ0PU Zero-sequence impedance of a zig-zag grounding bank, in pu.
z = z0_ohm_per_phase / (v_kv_ll^2 / s_base_mva);
end
