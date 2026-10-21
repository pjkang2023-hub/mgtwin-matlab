classdef TagRule
    %TAGRULE One line of a site's naming convention.
    %   A regular expression with a named token `id` (and `meas`, unless the
    %   rule fixes MEASUREMENT), the entity kind it names, an optional
    %   ID_TEMPLATE ("{id}" by default; a template without "{id}" names one
    %   entity and needs no token) and a map from the site's measurement codes
    %   to the canonical ones. Python's (?P<name>...) is accepted as MATLAB's
    %   (?<name>...). Like Python's re.match, the pattern must match from the
    %   tag's first character.
    properties (Constant)
        %MEASUREMENTS Canonical measurements and their dimension.
        MEASUREMENTS = dictionary(["P", "Q", "S", "V", "I", "F", "SOC", "POS", "TEMP"], ...
            ["power", "reactive", "apparent", "voltage", "current", "frequency", "fraction", "state", "temperature"])
        %KINDS Entity kinds, and the Site property that lists them.
        KINDS = dictionary(["bus", "branch", "transformer", "switch", "converter", "machine", "load"], ...
            ["buses", "branches", "transformers", "switches", "converters", "machines", "loads"])
    end
    properties
        pattern (1,1) string = ""
        kind (1,1) string = ""
        meas_map = dictionary(string.empty, string.empty)   % site code -> canonical measurement
        measurement (1,1) string = ""                        % "" = taken from the meas token
        id_template (1,1) string = "{id}"
    end
    properties (SetAccess = private)
        rx (1,1) string = ""            % the pattern in MATLAB syntax
        tokens (1,:) string = string.empty(1,0)
    end
    methods
        function obj = TagRule(opts)
            arguments
                opts.pattern (1,1) string
                opts.kind (1,1) string
                opts.meas_map = dictionary(string.empty, string.empty)
                opts.measurement (1,1) string = ""
                opts.id_template (1,1) string = "{id}"
            end
            if mgtwin.internal.requireFields(opts, ["pattern", "kind"], "TagRule"), return; end
            if isstruct(opts.meas_map)        % from JSON
                m = dictionary(string.empty, string.empty);
                for f = string(fieldnames(opts.meas_map))', m(f) = string(opts.meas_map.(f)); end
                opts.meas_map = m;
            end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
            kinds = keys(mgtwin.TagRule.KINDS);
            if ~ismember(obj.kind, kinds)
                error("mgtwin:ValueError", "rule '%s': unknown kind '%s' (one of ['%s'])", ...
                    obj.pattern, obj.kind, strjoin(sort(kinds), "', '"));
            end
            used = string.empty(1,0);
            if isConfigured(obj.meas_map), used = reshape(values(obj.meas_map), 1, []); end
            if strlength(obj.measurement) > 0, used(end+1) = obj.measurement; end
            bad = unique(setdiff(used, keys(mgtwin.TagRule.MEASUREMENTS)));
            if ~isempty(bad)
                error("mgtwin:ValueError", "rule '%s': unknown measurement(s) ['%s']", obj.pattern, strjoin(bad, "', '"));
            end
            obj.rx = replace(obj.pattern, "(?P<", "(?<");
            t = regexp(obj.rx, "\(\?<(\w+)>", "tokens");
            obj.tokens = string(cellfun(@(c) c{1}, t, "UniformOutput", false));
            if ~ismember("id", obj.tokens) && contains(obj.id_template, "{id}")
                error("mgtwin:ValueError", "rule '%s' has no named group 'id' and its id_template needs one", obj.pattern);
            end
            if strlength(obj.measurement) == 0 && ~ismember("meas", obj.tokens)
                error("mgtwin:ValueError", "rule '%s' neither captures 'meas' nor fixes a measurement", obj.pattern);
            end
        end

        function hit = apply(obj, tag)
            %APPLY struct(kind, id, meas, code) or [] when the rule does not match;
            %   meas is "" when the code is not in the map, code "" when not captured.
            hit = [];
            [names, st] = regexp(tag, obj.rx, "names", "start", "once");
            if isempty(st) || st ~= 1, return; end
            code = "";
            if ismember("meas", obj.tokens), code = string(names.meas); end
            if strlength(obj.measurement) > 0
                meas = obj.measurement;
            elseif isConfigured(obj.meas_map) && isKey(obj.meas_map, code)
                meas = obj.meas_map(code);
            else
                meas = "";
            end
            if ismember("id", obj.tokens)
                eid = replace(obj.id_template, "{id}", string(names.id));
            else
                eid = obj.id_template;
            end
            hit = struct("kind", obj.kind, "id", eid, "meas", meas, "code", code);
        end
    end
end
