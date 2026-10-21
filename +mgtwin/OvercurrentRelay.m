classdef OvercurrentRelay
    %OVERCURRENTRELAY The relay on one breaker.
    %   Its protection elements are FUNCTIONS (mgtwin.ProtectionFunction); the
    %   legacy fields (pickup_a, curve, time_dial, directional) declare one
    %   phase overcurrent element active in every settings group - a 67
    %   forward when DIRECTIONAL, else a 51 - so a Site written before v0.6.8
    %   reads as it did. Pickup is stored in amperes, deliberately, because
    %   that is how it is set in the field and converting it is where errors
    %   enter.
    properties
        id (1,1) string = ""
        switch_id (1,1) string = ""
        ct_ratio double = []            % e.g. 600.0 for 600:5; [] until the design declares it
        pickup_a double = []            % primary amperes; [] = no legacy element
        curve (1,1) string = "IEC-VI"
        time_dial double = []
        directional (1,1) logical = false
        functions (1,:) mgtwin.ProtectionFunction = mgtwin.ProtectionFunction.empty(1,0)
        notes (1,1) string = ""
    end
    methods
        function obj = OvercurrentRelay(opts)
            arguments
                opts.id (1,1) string
                opts.switch_id (1,1) string
                opts.ct_ratio double {mustBeScalarOrEmpty, mustBePositive} = []
                opts.pickup_a double {mustBeScalarOrEmpty, mustBePositive} = []
                opts.curve (1,1) string = "IEC-VI"
                opts.time_dial double {mustBeScalarOrEmpty, mustBePositive} = []
                opts.directional (1,1) logical = false
                opts.functions (1,:) mgtwin.ProtectionFunction = mgtwin.ProtectionFunction.empty(1,0)
                opts.notes (1,1) string = ""
            end
            if mgtwin.internal.requireFields(opts, ["id", "switch_id"], "OvercurrentRelay"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
            if isempty(obj.pickup_a) && isempty(obj.functions)
                error("mgtwin:ValidationError", ...
                    "relay '%s' declares no protection element (pickup_a or functions)", obj.id);
            end
        end

        function e = legacyElement(obj)
            %LEGACYELEMENT The element the legacy fields declare, or empty.
            e = mgtwin.ProtectionFunction.empty(1,0);
            if isempty(obj.pickup_a), return; end
            if obj.directional, ansi = "67"; dir = "forward"; else, ansi = "51"; dir = "none"; end
            args = {"ansi", ansi, "pickup_a", obj.pickup_a, "direction", dir, "curve", obj.curve, ...
                    "notes", mgtwin.ProtectionFunction.LEGACY_ELEMENT};
            if ~isempty(obj.time_dial), args = [args, {"time_dial", obj.time_dial}]; end
            e = mgtwin.ProtectionFunction(args{:});
        end

        function es = elements(obj)
            es = [obj.legacyElement(), obj.functions];
        end

        function es = active(obj, group)
            %ACTIVE The elements active in settings group GROUP.
            es = obj.elements();
            if isempty(es), return; end
            es = es(arrayfun(@(e) e.activeIn(group), es));
        end
    end
end
