classdef Verdict
    %VERDICT Identification outcome. Anything short of IDENTIFIED is the gate
    %   declining to certify.
    enumeration
        IDENTIFIED          ("identified")
        WEAKLY_IDENTIFIED   ("weakly_identified")
        NOT_IDENTIFIABLE    ("not_identifiable")
        STRUCTURAL_MISMATCH ("structural_mismatch")
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = Verdict(v)
            obj.Value = v;
        end
        function tf = isRefusal(obj)
            tf = obj ~= mgtwin.Verdict.IDENTIFIED;
        end
    end
end
