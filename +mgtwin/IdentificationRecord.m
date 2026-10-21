classdef IdentificationRecord
    %IDENTIFICATIONRECORD What identifyMulti established for one source, as
    %   the envelope needs it: its verdict and the load-step amplitudes (pu on
    %   the source's rating) the experiments spanned. A step beyond them is an
    %   extrapolation.
    properties
        source_id (1,1) string = ""
        verdict (1,1) string = ""            % a Verdict value, e.g. "identified"
        step_range_pu (1,2) double = [NaN NaN]
        parameters (1,1) struct = struct()
    end
    methods
        function obj = IdentificationRecord(opts)
            arguments
                opts.source_id (1,1) string
                opts.verdict (1,1) string
                opts.step_range_pu (1,2) double
                opts.parameters (1,1) struct = struct()
            end
            if mgtwin.internal.requireFields(opts, ["source_id", "verdict", "step_range_pu"], "IdentificationRecord"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
        function tf = identified(obj)
            tf = obj.verdict == "identified";
        end
    end
end
