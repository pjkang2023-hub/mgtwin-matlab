function c = gateProtectionConstants()
%GATEPROTECTIONCONSTANTS Tunables of the protection gate.
%   PROTECTION_MARGIN   dependability margin over pickup (x)
%   CONVERTER_DOMINANCE converter share of fault current above which
%                       magnitude-based grading is structurally marginal
c = struct("PROTECTION_MARGIN", 1.5, "CONVERTER_DOMINANCE", 0.80);
end
