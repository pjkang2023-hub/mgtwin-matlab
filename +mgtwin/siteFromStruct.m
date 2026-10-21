function site = siteFromStruct(s)
%SITEFROMSTRUCT Build a validated mgtwin.Site from a decoded JSON struct.
%
%   S is what jsondecode returns for a Site as Python's mgtwin writes it
%   (Site.model_dump_json): snake_case fields, enums as their values, null
%   for a field not declared. A missing or null field takes the class
%   default, as pydantic does; validation runs in the constructors.
%
%   See also mgtwin.siteFromJson.
arguments
    s (1,1) struct
end
spec = { ...
    "buses",        @mgtwin.Bus,             struct(); ...
    "branches",     @mgtwin.Branch,          struct(); ...
    "transformers", @mgtwin.Transformer,     struct("hv_config", "mgtwin.WindingConfig", "lv_config", "mgtwin.WindingConfig"); ...
    "switches",     @mgtwin.Switch,          struct(); ...
    "relays",       @mgtwin.OvercurrentRelay, struct(); ...
    "converters",   @mgtwin.Converter,       struct("control", "mgtwin.ConverterControl", "sign", "mgtwin.PowerSign"); ...
    "machines",     @mgtwin.SynchronousGen,  struct(); ...
    "loads",        @mgtwin.Load,            struct("model", "mgtwin.LoadModel", "sign", "mgtwin.PowerSign"); ...
    "grounding",    @mgtwin.GroundingSource, struct("kind", "mgtwin.GroundingKind"); ...
    "islands",      @mgtwin.IslandConfig,    struct()};
args = {"id", string(s.id), "base", build(@mgtwin.Base, s.base, struct())};
if isfield(s, "name") && ~isempty(s.name), args = [args, {"name", string(s.name)}]; end
for k = 1:size(spec, 1)
    field = spec{k, 1};
    if ~isfield(s, field) || isempty(s.(field)), continue; end
    items = s.(field);
    if ~iscell(items), items = num2cell(items); end   % jsondecode: struct array or cell
    objs = cellfun(@(it) build(spec{k, 2}, it, spec{k, 3}), items(:), "UniformOutput", false);
    objs = vertcat(objs{:});
    args = [args, {field, objs}]; %#ok<AGROW>
end
site = mgtwin.Site(args{:});
end

function obj = build(ctor, item, enums)
nv = {};
for f = string(fieldnames(item))'
    v = item.(f);
    if isempty(v) && ~ischar(v) && ~iscell(v), continue; end   % JSON null: the default
    if f == "load_factors"
        % a JSON object id -> factor: jsondecode gives a struct, its keys as field names
        nv = [nv, {char(f), v}]; %#ok<AGROW>
        continue
    end
    if isfield(enums, f)
        v = mgtwin.internal.enumFromValue(enums.(f), v);
    elseif f == "params"
        v = build(@mgtwin.ConverterParams, v, struct());
    elseif f == "functions"
        if ~iscell(v), v = num2cell(v); end
        fs = cellfun(@(it) build(@mgtwin.ProtectionFunction, it, struct()), v(:)', "UniformOutput", false);
        v = [fs{:}];
    elseif iscell(v) || ischar(v)
        v = string(v);
        if ~isscalar(v) || iscell(item.(f)), v = reshape(v, 1, []); end
    elseif isnumeric(v) && ~isscalar(v)
        v = reshape(v, 1, []);
    end
    nv = [nv, {char(f), v}]; %#ok<AGROW>
end
obj = ctor(nv{:});
end
