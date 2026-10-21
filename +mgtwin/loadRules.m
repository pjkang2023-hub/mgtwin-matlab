function rules = loadRules(path)
%LOADRULES Tag rules from a JSON list of {pattern, kind, meas_map?, measurement?, id_template?}.
arguments
    path (1,1) string
end
items = jsondecode(fileread(path));
if ~iscell(items), items = num2cell(items); end
rules = mgtwin.TagRule.empty(1,0);
for k = 1:numel(items)
    it = items{k};
    nv = {};
    for f = string(fieldnames(it))'
        v = it.(f);
        if isempty(v) && ~isstruct(v), continue; end   % JSON null: the default
        if ischar(v), v = string(v); end
        nv = [nv, {char(f), v}]; %#ok<AGROW>
    end
    rules(end+1) = mgtwin.TagRule(nv{:}); %#ok<AGROW>
end
end
