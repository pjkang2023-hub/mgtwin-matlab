function tags = readTags(path)
%READTAGS A tag list from CSV with a `tag` column and optional `unit`,
%   `description`, `sample_period_s`.
arguments
    path (1,1) string
end
opts = detectImportOptions(path, "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",");
opts = setvartype(opts, opts.VariableNames, "string");
T = readtable(path, opts);
cols = string(T.Properties.VariableNames);
if ~ismember("tag", cols)
    error("mgtwin:ValueError", "%s: no 'tag' column (columns: ['%s'])", path, strjoin(sort(cols), "', '"));
end
get = @(c, k) iif(ismember(c, cols), @() strtrim(T.(c)(k)), "");
tags = mgtwin.Tag.empty(1,0);
for k = 1:height(T)
    p = get("sample_period_s", k);
    if ismissing(p) || strlength(p) == 0, p = []; else, p = str2double(p); end
    u = get("unit", k); if ismissing(u), u = ""; end
    d = get("description", k); if ismissing(d), d = ""; end
    tags(end+1) = mgtwin.Tag(tag=strtrim(T.tag(k)), unit=u, description=d, sample_period_s=p); %#ok<AGROW>
end
end

function v = iif(cond, f, other)
if cond, v = f(); else, v = other; end
end
