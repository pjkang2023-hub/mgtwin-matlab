classdef GroundingSource
    %GROUNDINGSOURCE A zero-sequence source: a grounded transformer neutral, a
    %   dedicated grounding transformer (zig-zag or grounded-wye/delta), or a
    %   machine neutral.
    %
    %   `available_when_islanded` is the field that matters. A microgrid whose
    %   only grounding reference sits on the utility side of the point of
    %   interconnection becomes ungrounded the moment it islands, with SLG
    %   overvoltages up to ~sqrt(3) on the unfaulted phases. That is a safety
    %   finding, not an accuracy finding.
    properties
        id (1,1) string = ""
        bus (1,1) string = ""
        kind (1,1) mgtwin.GroundingKind = mgtwin.GroundingKind.UNGROUNDED
        z0_ohm (1,1) double = 0          % zero-sequence grounding impedance
        available_when_islanded (1,1) logical = false
        notes (1,1) string = ""
    end
    methods
        function obj = GroundingSource(opts)
            arguments
                opts.id (1,1) string
                opts.bus (1,1) string
                opts.kind (1,1) mgtwin.GroundingKind
                opts.z0_ohm (1,1) double {mustBeNonnegative} = 0
                opts.available_when_islanded (1,1) logical
                opts.notes (1,1) string = ""
            end
            if mgtwin.internal.requireFields(opts, ["id", "bus", "kind", "available_when_islanded"], "GroundingSource"), return; end
            obj.id = opts.id; obj.bus = opts.bus; obj.kind = opts.kind;
            obj.z0_ohm = opts.z0_ohm;
            obj.available_when_islanded = opts.available_when_islanded;
            obj.notes = opts.notes;
            if obj.kind == mgtwin.GroundingKind.SOLID && obj.z0_ohm > 1.0
                error("mgtwin:ValidationError", ...
                    "grounding source '%s' declares solid grounding but z0_ohm=%g; " + ...
                    "declare LOW_RESISTANCE or REACTANCE instead", obj.id, obj.z0_ohm);
            end
            if obj.kind == mgtwin.GroundingKind.UNGROUNDED && obj.z0_ohm ~= 0
                error("mgtwin:ValidationError", ...
                    "grounding source '%s' is UNGROUNDED; z0_ohm is meaningless", obj.id);
            end
        end
    end
end
