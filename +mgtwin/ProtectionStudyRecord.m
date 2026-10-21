classdef ProtectionStudyRecord
    %PROTECTIONSTUDYRECORD A protection study's verdict on one state, from the
    %   tool that computes fault currents (Electrisim: IEC 60909 and EMT fault
    %   levels at each relay, grading, settings). PASSED is the study's own
    %   conclusion; MODELS_IDENTIFIED says whether its converter current
    %   limits and ride-through were identified from measured response or the
    %   vendors' assumed models.
    properties
        state_id (1,1) string = ""
        tool (1,1) string = ""
        passed (1,1) logical = false
        models_identified (1,1) logical = false
        reference (1,1) string = ""
        notes (1,1) string = ""
    end
    methods
        function obj = ProtectionStudyRecord(opts)
            arguments
                opts.state_id (1,1) string
                opts.tool (1,1) string
                opts.passed (1,1) logical
                opts.models_identified (1,1) logical = false
                opts.reference (1,1) string = ""
                opts.notes (1,1) string = ""
            end
            if mgtwin.internal.requireFields(opts, ["state_id", "tool", "passed"], "ProtectionStudyRecord"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
    end
end
