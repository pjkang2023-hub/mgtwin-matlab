classdef Scenario
    %SCENARIO One truth-plant case of the identification eval battery.
    properties
        name (1,1) string = ""
        params (1,1) mgtwin.PlantParams = mgtwin.PlantParams()
        mismatch (1,1) logical = false      % is the library form structurally wrong?
        quantize_pu double = []             % measurement quantization step
        note (1,1) string = ""
        step (1,2) double = [0.20, 0.60]    % [p_before, p_after]
    end
    methods
        function obj = Scenario(opts)
            arguments
                opts.name (1,1) string
                opts.params (1,1) mgtwin.PlantParams
                opts.mismatch (1,1) logical
                opts.quantize_pu double = []
                opts.note (1,1) string = ""
                opts.step (1,2) double = [0.20, 0.60]
            end
            if mgtwin.internal.requireFields(opts, ["name", "params", "mismatch"], "Scenario"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
    end
end
