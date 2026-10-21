function out = polar(v)
%POLAR [magnitude, angle_deg] rows for reporting: out(k,:) = [|v_k|, angle_deg].
v = v(:);
out = [abs(v), rad2deg(angle(v))];
end
