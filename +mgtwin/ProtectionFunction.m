classdef ProtectionFunction
    %PROTECTIONFUNCTION One protection element on a breaker's relay.
    %   Pickup is primary amperes, as it is set in the field; [] for elements
    %   set otherwise (a differential's bias, a voltage or frequency element).
    %   GROUPS names the settings groups the element is active in - empty
    %   means every group - and a state selects one (IslandConfig.
    %   settings_group). A unit element's zone is the buses it covers.
    properties (Constant)
        %ANSI_FUNCTIONS ANSI device functions a relay may declare, and what each is.
        ANSI_FUNCTIONS = dictionary( ...
            ["50", "51", "50N", "51N", "50G", "51G", "67", "67N", "51V", "21", ...
             "87L", "87B", "87T", "27", "59", "59N", "81U", "81O", "50BF"], ...
            ["phase instantaneous overcurrent", "phase time overcurrent", ...
             "residual instantaneous overcurrent", "residual time overcurrent", ...
             "ground instantaneous overcurrent", "ground time overcurrent", ...
             "directional phase overcurrent", "directional earth-fault overcurrent", ...
             "voltage-restrained / -controlled overcurrent", "distance", ...
             "line differential", "bus differential", "transformer differential", ...
             "undervoltage", "overvoltage", "neutral overvoltage", ...
             "underfrequency", "overfrequency", "breaker failure"])
        %PHASE_OC Phase elements whose operation rests on fault-current magnitude.
        PHASE_OC = ["50", "51", "67"]
        %EARTH_OC Earth-fault elements: their magnitude is the zero-sequence path's.
        EARTH_OC = ["50N", "51N", "50G", "51G", "67N"]
        UNIT = ["87L", "87B", "87T"]
        %NOT_MAGNITUDE Elements whose discrimination does not rest on current magnitude alone.
        NOT_MAGNITUDE = ["87L", "87B", "87T", "51V", "21"]
        %LEGACY_ELEMENT The note on the element a relay's legacy fields declare.
        LEGACY_ELEMENT = "from the relay's pickup_a / curve / time_dial / directional"
    end
    properties
        ansi (1,1) string = ""
        pickup_a double = []          % primary amperes; [] = not set by current
        direction (1,1) string = "none"   % "none" | "forward" | "reverse"
        curve (1,1) string = ""
        time_dial double = []
        groups (1,:) string = string.empty(1,0)
        zone_buses (1,:) string = string.empty(1,0)
        notes (1,1) string = ""
    end
    methods
        function obj = ProtectionFunction(opts)
            arguments
                opts.ansi (1,1) string
                opts.pickup_a double {mustBeScalarOrEmpty, mustBePositive} = []
                opts.direction (1,1) string {mustBeMember(opts.direction, ["none", "forward", "reverse"])} = "none"
                opts.curve (1,1) string = ""
                opts.time_dial double {mustBeScalarOrEmpty, mustBePositive} = []
                opts.groups (1,:) string = string.empty(1,0)
                opts.zone_buses (1,:) string = string.empty(1,0)
                opts.notes (1,1) string = ""
            end
            if mgtwin.internal.requireFields(opts, "ansi", "ProtectionFunction"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
            known = keys(mgtwin.ProtectionFunction.ANSI_FUNCTIONS);
            if ~ismember(obj.ansi, known)
                error("mgtwin:ValidationError", "unknown ANSI function '%s' (one of ['%s'])", ...
                    obj.ansi, strjoin(sort(known), "', '"));
            end
            if startsWith(obj.ansi, "67") && obj.direction == "none"
                error("mgtwin:ValidationError", "a %s element needs a direction", obj.ansi);
            end
            if ismember(obj.ansi, mgtwin.ProtectionFunction.UNIT) && isempty(obj.zone_buses)
                error("mgtwin:ValidationError", "a %s element needs its zone's buses", obj.ansi);
            end
        end

        function tf = isDirectional(obj)
            tf = obj.direction ~= "none" || ismember(obj.ansi, mgtwin.ProtectionFunction.UNIT);
        end

        function tf = activeIn(obj, group)
            tf = isempty(obj.groups) || ismember(group, obj.groups);
        end
    end
end
