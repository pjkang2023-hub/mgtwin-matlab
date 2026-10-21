function site = siteFromJson(source)
%SITEFROMJSON Read a Site written by Python's mgtwin (model_dump_json).
%   site = mgtwin.siteFromJson("examples/c003_revC_site.json") reads a file;
%   a char/string that starts with "{" is decoded as JSON text instead.
%
%   See also mgtwin.siteFromStruct.
arguments
    source (1,1) string
end
txt = source;
if ~startsWith(strtrim(source), "{")
    txt = fileread(source);
end
site = mgtwin.siteFromStruct(jsondecode(txt));
end
