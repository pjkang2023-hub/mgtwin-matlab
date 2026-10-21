function res = slgFault(z1_pu, opts)
%SLGFAULT Single-line-to-ground fault analysis by symmetrical components.
%
%   res = mgtwin.slgFault(z1_pu, z2_pu=[], z0_pu=[], zf_pu=0, v_prefault_pu=1)
%
%   This is the quantitative face of gateGrounding: where the gate says
%   "this zone has no zero-sequence source", this function says what that
%   costs -- unfaulted-phase overvoltage approaching sqrt(3) pu and a
%   ground-fault current approaching zero (so nothing current-based can
%   detect the fault).
%
%   Sequence networks for an SLG fault on phase a through fault impedance Zf:
%       I1 = I2 = I0 = Vf / (Z1 + Z2 + Z0 + 3 Zf)
%       V1 = Vf - Z1 I1      V2 = -Z2 I2      V0 = -Z0 I0
%       Va = V0 + V1 + V2
%       Vb = V0 + a^2 V1 + a V2
%       Vc = V0 + a  V1 + a^2 V2
%
%   z0_pu = [] means NO zero-sequence path (ungrounded zone): handled as an
%   exact limit, not a big number: I -> 0, V0 -> -Vf, so Vb = Vf (a^2 - 1)
%   and Vc = Vf (a - 1), both of magnitude sqrt(3) Vf. z2_pu defaults to
%   z1_pu. All impedances Thevenin at the fault bus, per unit on a common base.
arguments
    z1_pu (1,1) double
    opts.z2_pu double = []
    opts.z0_pu double = []
    opts.zf_pu (1,1) double = 0.0
    opts.v_prefault_pu (1,1) double = 1.0
end
A = exp(2i * pi / 3);
z1 = complex(z1_pu);
if isempty(opts.z2_pu), z2 = z1; else, z2 = complex(opts.z2_pu); end
vf = complex(opts.v_prefault_pu);

if isempty(opts.z0_pu)
    % Z0 -> infinity limit.
    vb = vf * (A^2 - 1.0);
    vc = vf * (A - 1.0);
    res = mgtwin.SLGResult(0.0, [complex(0), vb, vc], max(abs(vb), abs(vc)), false);
    return;
end

z0 = complex(opts.z0_pu);
i_seq = vf / (z1 + z2 + z0 + 3.0 * complex(opts.zf_pu));
v1 = vf - z1 * i_seq;
v2 = -z2 * i_seq;
v0 = -z0 * i_seq;
va = v0 + v1 + v2;
vb = v0 + A^2 * v1 + A * v2;
vc = v0 + A * v1 + A^2 * v2;
res = mgtwin.SLGResult(3.0 * i_seq, [va, vb, vc], max(abs(vb), abs(vc)), true);
end
