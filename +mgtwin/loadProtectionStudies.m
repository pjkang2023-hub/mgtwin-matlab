function recs = loadProtectionStudies(path)
%LOADPROTECTIONSTUDIES Protection-study records from a JSON list of
%   {state_id, tool, passed, models_identified?, reference?, notes?}.
arguments
    path (1,1) string
end
items = jsondecode(fileread(path));
if ~iscell(items), items = num2cell(items); end
recs = mgtwin.ProtectionStudyRecord.empty(1,0);
for k = 1:numel(items)
    it = items{k};
    nv = {};
    for f = string(fieldnames(it))'
        v = it.(f);
        if ischar(v), v = string(v); end
        nv = [nv, {char(f), v}]; %#ok<AGROW>
    end
    recs(end+1) = mgtwin.ProtectionStudyRecord(nv{:}); %#ok<AGROW>
end
end
